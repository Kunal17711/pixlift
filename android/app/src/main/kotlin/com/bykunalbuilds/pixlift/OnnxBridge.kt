package com.bykunalbuilds.pixlift

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge between the Flutter UI and ONNX Runtime.
 *
 * All ONNX work (model load + per-tile inference + final encode) runs on a
 * single background executor thread, never on the platform/UI thread, so the
 * Flutter UI stays responsive. Duplicate simultaneous inference is prevented
 * because only one background worker schedules runs at a time.
 *
 * Channel: com.bykunalbuilds.pixlift/onnx
 *   init(modelPath)                       -> loads the bundled ONNX session
 *   upscaleTile(inputChw,h,w,scale,outPath) -> AI inference, writes RGB
 *   encodeImage(rawPath,w,h,format,q,out) -> PNG/JPEG encode
 *   state()                               -> {'ready': bool}
 *   dispose()                             -> releases the session
 */
class OnnxBridge(messenger: io.flutter.plugin.common.BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.bykunalbuilds.pixlift/onnx")
    private val onnx = OnnxEngine()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                val path = call.argument<String>("modelPath") ?: ""
                onnx.initAsync(path) { err ->
                    reply(result) {
                        if (err != null) result.error(errorCode(err), err, null)
                        else result.success(mapOf("ready" to true))
                    }
                }
            }
            "upscaleTile" -> {
                val input = call.argument<ByteArray>("input")
                val h = call.argument<Int>("h") ?: 0
                val w = call.argument<Int>("w") ?: 0
                val scale = call.argument<Int>("scale") ?: 4
                val outPath = call.argument<String>("outPath") ?: ""
                onnx.upscaleTileAsync(input, h, w, scale, outPath) { outH, outW, err ->
                    reply(result) {
                        if (err != null) result.error(errorCode(err), err, null)
                        else result.success(mapOf("outH" to outH, "outW" to outW))
                    }
                }
            }
            "encodeImage" -> {
                onnx.encodeImageAsync(
                    call.argument<String>("rawPath") ?: "",
                    call.argument<Int>("w") ?: 0,
                    call.argument<Int>("h") ?: 0,
                    call.argument<String>("format") ?: "png",
                    call.argument<Int>("quality") ?: 96,
                    call.argument<String>("outPath") ?: ""
                ) { err ->
                    reply(result) {
                        if (err != null) result.error(errorCode(err), err, null)
                        else result.success(true)
                    }
                }
            }
            "state" -> result.success(mapOf("ready" to onnx.isReady))
            "dispose" -> {
                onnx.dispose()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun reply(result: MethodChannel.Result, action: () -> Unit) {
        mainHandler.post { action() }
    }

    private fun errorCode(message: String): String =
        if (message.startsWith("LOW_MEMORY:")) "LOW_MEMORY" else "NATIVE_FAILURE"
}
