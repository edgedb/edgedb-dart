class ProtocolError extends Error {
  final String message;
  ProtocolError(this.message);

  @override
  String toString() {
    return 'ProtocolError: $message';
  }
}
