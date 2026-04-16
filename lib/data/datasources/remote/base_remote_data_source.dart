import 'package:flutter_app_demo/core/network/api_client.dart';

abstract class BaseRemoteDataSource {
  const BaseRemoteDataSource(this.apiClient);

  final ApiClient apiClient;
}
