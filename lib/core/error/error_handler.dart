import 'dart:io';

import 'app_exception.dart';
import 'failure.dart';

class ErrorHandler {
  const ErrorHandler._();

  static Failure handle(Object error) {
    if (error is Failure) {
      return error;
    }

    if (error is AppException) {
      return Failure(
        message: error.message,
        code: error.code,
        statusCode: error.statusCode,
      );
    }

    if (error is SocketException) {
      return const Failure(
        message: 'No internet connection. Please try again.',
        code: 'network_error',
      );
    }

    if (error is FormatException) {
      return const Failure(
        message: 'Invalid response format.',
        code: 'serialization_error',
      );
    }

    return Failure(message: error.toString(), code: 'unknown_error');
  }
}
