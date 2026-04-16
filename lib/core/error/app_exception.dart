class AppException implements Exception {
  const AppException({required this.message, this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('AppException: $message');
    if (code != null) {
      buffer.write(' (code: $code)');
    }
    if (statusCode != null) {
      buffer.write(' (status: $statusCode)');
    }
    return buffer.toString();
  }
}

class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.statusCode,
  });
}

class ApiException extends AppException {
  const ApiException({required super.message, super.code, super.statusCode});
}

class SerializationException extends AppException {
  const SerializationException({
    required super.message,
    super.code,
    super.statusCode,
  });
}

class UnknownException extends AppException {
  const UnknownException({
    required super.message,
    super.code,
    super.statusCode,
  });
}
