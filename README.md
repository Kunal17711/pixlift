# PixLift for Android

PixLift is a free, private, on-device AI photo upscaler by Kunal Builds. It
uses the compact Real-ESRGAN `realesr-general-x4v3` model through ONNX Runtime
and supports genuine 2× and 4× output.

Images are selected with Android's system photo picker and processed locally.
The release manifest does not request internet access. PixLift contains no
accounts, ads, analytics, tracking, remote inference, or watermarking.

## Development

The project uses Flutter 3.41 or newer and Android API 24 or newer.

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Release signing is read from `android/key.properties` when present. Local
unsigned-release validation falls back to the debug key; do not publish that
artifact. Model and runtime licensing is documented in
`THIRD_PARTY_NOTICES.md`.
