import 'dart:convert';
import 'dart:io';

import '../constants/app_constants.dart';
import '../error/app_exception.dart';

class ApiResponse<T> {
  const ApiResponse({
    required this.statusCode,
    required this.data,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final T data;
  final Map<String, String> headers;
}

class ApiClient {
  ApiClient({required this.baseUrl, HttpClient? httpClient, Duration? timeout})
    : _httpClient = httpClient ?? HttpClient(),
      _timeout = timeout ?? AppConstants.apiTimeout;

  final String baseUrl;
  final HttpClient _httpClient;
  final Duration _timeout;

  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      method: 'GET',
      path: path,
      headers: headers,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      method: 'POST',
      path: path,
      headers: headers,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> put(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      method: 'PUT',
      path: path,
      headers: headers,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) {
    return _send(
      method: 'DELETE',
      path: path,
      headers: headers,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> _send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters?.map(
        (String key, dynamic value) => MapEntry(key, value.toString()),
      ),
    );

    try {
      final HttpClientRequest request = await _httpClient
          .openUrl(method, uri)
          .timeout(_timeout);

      final Map<String, String> allHeaders = <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
      };

      allHeaders.forEach(request.headers.set);

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final HttpClientResponse response = await request.close().timeout(
        _timeout,
      );
      final String raw = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> payload = _decodePayload(raw);

      if (response.statusCode >= 400) {
        throw ApiException(
          message: payload['message']?.toString() ?? 'Request failed.',
          statusCode: response.statusCode,
          code: payload['code']?.toString(),
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        statusCode: response.statusCode,
        data: payload,
        headers: _flattenHeaders(response.headers),
      );
    } on SocketException catch (error) {
      throw NetworkException(message: error.message);
    } on FormatException catch (error) {
      throw SerializationException(message: error.message);
    } on AppException {
      rethrow;
    } catch (error) {
      throw UnknownException(message: error.toString());
    }
  }

  Map<String, dynamic> _decodePayload(String raw) {
    if (raw.isEmpty) {
      return <String, dynamic>{};
    }

    final dynamic decoded = jsonDecode(raw);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is List<dynamic>) {
      return <String, dynamic>{'items': decoded};
    }

    return <String, dynamic>{'value': decoded};
  }

  Map<String, String> _flattenHeaders(HttpHeaders headers) {
    final Map<String, String> data = <String, String>{};

    headers.forEach((String name, List<String> values) {
      if (values.isNotEmpty) {
        data[name] = values.join(',');
      }
    });

    return data;
  }
}
