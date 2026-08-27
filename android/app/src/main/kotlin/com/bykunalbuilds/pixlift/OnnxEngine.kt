package com.bykunalbuilds.pixlift

/** Pure native codec: ONNX inference plus bounded-memory PNG/JPEG encode. */
internal class OnnxEngine {
    private var env: ai.onnxruntime.OrtEnvironment? = null
    private var session: ai.onnxruntime.OrtSession? = null
    private var ready = false
    private val lock = Any()
    private val executor = java.util.concurrent.Executors.newSingleThreadExecutor()

    val isReady: Boolean get() = synchronized(lock) { ready }

    fun initAsync(modelPath: String, onDone: (String?) -> Unit) {
        executor.execute {
            if (isReady) {
                onDone(null)
                return@execute
            }
            var err: String? = null
            try {
                // The official Android AAR includes optional telemetry. The
                // manifest initializer and network permissions are removed,
                // and this environment flag prevents the uploader, events,
                // and persistent device identifier from being created.
                android.system.Os.setenv("ORT_DISABLE_TELEMETRY", "1", true)
                val e = ai.onnxruntime.OrtEnvironment.getEnvironment()
                val opts = ai.onnxruntime.OrtSession.SessionOptions()
                opts.setIntraOpNumThreads(4)
                opts.setOptimizationLevel(ai.onnxruntime.OrtSession.SessionOptions.OptLevel.ALL_OPT)
                val s = e.createSession(modelPath, opts)
                synchronized(lock) { env = e; session = s; ready = true }
            } catch (t: Throwable) {
                err = failure("Unable to load the AI model on this device", t)
            }
            onDone(err)
        }
    }

    fun upscaleTileAsync(
        inputChw: ByteArray?,
        h: Int,
        w: Int,
        scale: Int,
        outPath: String,
        onDone: (Int, Int, String?) -> Unit
    ) {
        executor.execute {
            var err: String? = null
            var outH = 0
            var outW = 0
            try {
                val (env, s) = requireSession()
                if (inputChw == null) throw IllegalStateException("missing tile input")
                val floatBuffer = java.nio.ByteBuffer.wrap(inputChw)
                    .order(java.nio.ByteOrder.LITTLE_ENDIAN)
                    .asFloatBuffer()
                require(scale == 2 || scale == 4) { "unsupported output scale" }
                ai.onnxruntime.OnnxTensor.createTensor(
                    env, floatBuffer, longArrayOf(1, 3, h.toLong(), w.toLong())
                ).use { inputTensor ->
                    s.run(mapOf("input" to inputTensor)).use { outputs ->
                        // Result#get already returns the OnnxValue. Calling
                        // `.value` here materializes a nested float array, so
                        // casting that value back to OnnxTensor fails at runtime.
                        val outT = outputs.get(0) as ai.onnxruntime.OnnxTensor
                        val shape = outT.info.shape
                        val modelOutH = shape[2].toInt()
                        val modelOutW = shape[3].toInt()
                        require(modelOutH == h * 4 && modelOutW == w * 4) {
                            "model returned ${modelOutW}x${modelOutH}"
                        }
                        val n = 3 * modelOutH * modelOutW
                        val floats = FloatArray(n)
                        val outputBuffer = outT.floatBuffer.duplicate()
                        outputBuffer.position(0)
                        outputBuffer.limit(n)
                        outputBuffer.get(floats)
                        outH = h * scale
                        outW = w * scale
                        writeInterleavedRgb(
                            floats, modelOutH, modelOutW, outH, outW, outPath
                        )
                    }
                }
            } catch (t: Throwable) {
                err = failure("Inference failed", t)
            }
            onDone(outH, outW, err)
        }
    }

    private data class Sess(val env: ai.onnxruntime.OrtEnvironment, val session: ai.onnxruntime.OrtSession)

    private fun requireSession(): Sess {
        synchronized(lock) {
            val e = env
            val s = session
            if (e != null && s != null) return Sess(e, s)
        }
        throw IllegalStateException("AI model is not loaded yet")
    }

    private fun writeInterleavedRgb(
        floats: FloatArray,
        modelOutH: Int,
        modelOutW: Int,
        outH: Int,
        outW: Int,
        outPath: String
    ) {
        val modelPixels = modelOutH * modelOutW
        val bytes = ByteArray(3 * outH * outW)
        val downsample = modelOutW / outW
        require(downsample == 1 || downsample == 2)
        var dst = 0
        for (y in 0 until outH) {
            val sy = y * downsample
            for (x in 0 until outW) {
                val sx = x * downsample
                for (c in 0 until 3) {
                    val plane = c * modelPixels
                    val value = if (downsample == 1) {
                        floats[plane + sy * modelOutW + sx]
                    } else {
                        (floats[plane + sy * modelOutW + sx] +
                            floats[plane + sy * modelOutW + sx + 1] +
                            floats[plane + (sy + 1) * modelOutW + sx] +
                            floats[plane + (sy + 1) * modelOutW + sx + 1]) * 0.25f
                    }
                    bytes[dst++] = clampByte(value)
                }
            }
        }
        java.io.BufferedOutputStream(java.io.FileOutputStream(outPath)).use { it.write(bytes) }
    }

    private fun clampByte(v: Float): Byte {
        val x = if (v < 0f) 0f else if (v > 1f) 1f else v
        return (x * 255f + 0.5f).toInt().toByte()
    }

    fun encodeImageAsync(
        rawPath: String,
        w: Int,
        h: Int,
        format: String,
        quality: Int,
        outPath: String,
        onDone: (String?) -> Unit
    ) {
        executor.execute {
            var err: String? = null
            var bitmap: android.graphics.Bitmap? = null
            try {
                require(w > 0 && h > 0) { "invalid output dimensions" }
                bitmap = android.graphics.Bitmap.createBitmap(
                    w, h, android.graphics.Bitmap.Config.ARGB_8888
                )
                val rowBytes = ByteArray(w * 3)
                val pixels = IntArray(w)
                java.io.DataInputStream(
                    java.io.BufferedInputStream(java.io.FileInputStream(rawPath))
                ).use { input ->
                    for (y in 0 until h) {
                        input.readFully(rowBytes)
                        var src = 0
                        for (x in 0 until w) {
                            val r = rowBytes[src++].toInt() and 0xff
                            val g = rowBytes[src++].toInt() and 0xff
                            val b = rowBytes[src++].toInt() and 0xff
                            pixels[x] = -0x1000000 or (r shl 16) or (g shl 8) or b
                        }
                        bitmap.setPixels(pixels, 0, w, 0, y, w, 1)
                    }
                }
                java.io.BufferedOutputStream(java.io.FileOutputStream(outPath)).use { stream ->
                    val ok = if (format == "jpg") {
                        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, quality, stream)
                    } else {
                        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
                    }
                    check(ok) { "bitmap encoder returned false" }
                }
            } catch (t: Throwable) {
                err = failure("Encode failed", t)
            } finally {
                bitmap?.recycle()
            }
            onDone(err)
        }
    }

    fun dispose() {
        synchronized(lock) {
            try { session?.close() } catch (_: Throwable) {}
            try { env?.close() } catch (_: Throwable) {}
            session = null
            env = null
            ready = false
        }
    }

    private fun failure(prefix: String, t: Throwable): String {
        val kind = if (t is OutOfMemoryError) "LOW_MEMORY:" else ""
        return "$kind$prefix. ${t.message ?: ""}"
    }
}
