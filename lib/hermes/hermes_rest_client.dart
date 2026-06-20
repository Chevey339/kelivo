import 'dart:convert';
import 'package:dio/dio.dart';
import 'hermes_auth.dart';

/// REST client wrapping [Dio] for Hermes backend REST API calls.
///
/// Automatically injects auth headers from the provided [HermesAuth].
class HermesRestClient {
  final HermesAuth _auth;
  late final Dio _dio;

  HermesRestClient({required HermesAuth auth, String? baseUrl, Dio? dio})
    : _auth = auth {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
    // Inject credentials for cookie-based auth (gated mode)
    _dio.options.extra['withCredentials'] = true;
  }

  /// GET request.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final headers = await _auth.authParams().then((a) => a.restHeaders);
    final resp = await _dio.get(
      path,
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );
    return _handleResponse(resp);
  }

  /// POST request.
  Future<dynamic> post(String path, {dynamic data}) async {
    final headers = await _auth.authParams().then((a) => a.restHeaders);
    final resp = await _dio.post(
      path,
      data: data,
      options: Options(headers: headers),
    );
    return _handleResponse(resp);
  }

  /// PUT request.
  Future<dynamic> put(String path, {dynamic data}) async {
    final headers = await _auth.authParams().then((a) => a.restHeaders);
    final resp = await _dio.put(
      path,
      data: data,
      options: Options(headers: headers),
    );
    return _handleResponse(resp);
  }

  /// DELETE request.
  Future<void> delete(String path) async {
    final headers = await _auth.authParams().then((a) => a.restHeaders);
    await _dio.delete(path, options: Options(headers: headers));
  }

  dynamic _handleResponse(Response resp) {
    if (resp.statusCode == null ||
        resp.statusCode! < 200 ||
        resp.statusCode! >= 300) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        message: 'HTTP ${resp.statusCode}',
      );
    }

    final data = resp.data;
    if (data is String) {
      if (data.startsWith('{') || data.startsWith('[')) {
        return jsonDecode(data);
      }
      return data;
    }
    return data;
  }
}
