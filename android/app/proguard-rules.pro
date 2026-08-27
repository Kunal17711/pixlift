# ---------- PixLift ProGuard / R8 rules ----------
# Keep rules are deliberately precise. We do not add blanket keep-all rules.

# ONNX Runtime uses JNI / native symbols; keep the Java binding intact.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
