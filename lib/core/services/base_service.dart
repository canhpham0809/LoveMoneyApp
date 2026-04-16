import '../error/error_handler.dart';
import '../network/api_client.dart';
import '../utils/result.dart';

abstract class BaseService {
  const BaseService(this.apiClient);

  final ApiClient apiClient;

  Future<Result<T>> execute<T>(Future<T> Function() action) async {
    try {
      final T data = await action();
      return Success<T>(data);
    } catch (error) {
      return FailureResult<T>(ErrorHandler.handle(error));
    }
  }
}
