class Failure {
  const Failure({required this.message, this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() {
    return 'Failure(message: $message, code: $code, statusCode: $statusCode)';
  }
}
