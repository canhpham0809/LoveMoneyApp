import 'package:flutter_app_demo/core/error/error_handler.dart';
import 'package:flutter_app_demo/core/utils/result.dart';

abstract class BaseRepository {
  const BaseRepository();

  Future<Result<T>> run<T>(Future<T> Function() action) async {
    try {
      final T data = await action();
      return Success<T>(data);
    } catch (error) {
      return FailureResult<T>(ErrorHandler.handle(error));
    }
  }
}
