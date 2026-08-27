/// User-facing error kinds. PixLift converts these into friendly messages and
/// never leaks technical stack traces to the UI.
enum PixLiftErrorKind {
  canceled,
  corruptedImage,
  unsupportedImage,
  modelLoadFailed,
  lowMemory,
  inferenceFailed,
  saveFailed,
  shareFailed,
  noStorage,
  unknown,
}

/// Wraps a failure with a user-safe description and a technical detail (kept
/// out of the UI but useful for local debugging logs).
class PixLiftException implements Exception {
  PixLiftException(this.kind, this.message, [this.technicalHint]);

  final PixLiftErrorKind kind;
  final String message;
  final String? technicalHint;

  bool get isCancellation => kind == PixLiftErrorKind.canceled;

  @override
  String toString() =>
      'PixLiftException(${kind.name}, $message)${technicalHint == null ? '' : ' [$technicalHint]'}';
}

/// Thrown when the user cancels the current run (superseded by a new pick).
class UpscaleCancelledException extends PixLiftException {
  UpscaleCancelledException()
    : super(PixLiftErrorKind.canceled, 'Process cancelled.');
}
