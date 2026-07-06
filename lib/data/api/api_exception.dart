class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final Object? body;

  @override
  String toString() {
    if (statusCode == null) return message;
    return '[$statusCode] $message';
  }
}
