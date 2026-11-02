/// Why an image could not be had: a status other than 200, a body that is not
/// a picture, one past the size cap, a timeout, or a connection that failed.
///
/// The message never carries the address. An image URL can hold a token, and
/// an error travels into logs and crash reports.
final class MagicImageException implements Exception {
  /// An exception that says [message].
  const MagicImageException(this.message);

  /// What went wrong, free of the address that was asked for.
  final String message;

  @override
  String toString() => 'MagicImageException: $message';
}
