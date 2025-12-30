/// Exception thrown when decryption fails.
class MagicDecryptException implements Exception {
  final String message;

  MagicDecryptException([this.message = 'The payload is invalid.']);

  @override
  String toString() => 'MagicDecryptException: $message';
}
