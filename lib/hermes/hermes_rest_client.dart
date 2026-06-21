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

  // ── Session REST ───────────────────────────────────────────────────────────

  /// List sessions with pagination.
  Future<Map<String, dynamic>> sessionsList({
    int? limit,
    int? offset,
    String? search,
  }) async {
    return await get(
          '/api/sessions',
          queryParameters: {
            if (limit != null) 'limit': limit,
            if (offset != null) 'offset': offset,
            if (search != null) 'search': search,
          },
        )
        as Map<String, dynamic>;
  }

  /// Get messages for a session.
  Future<List<dynamic>> sessionsMessages(String sessionId, {int? limit}) async {
    final result =
        await get(
              '/api/sessions/$sessionId/messages',
              queryParameters: {if (limit != null) 'limit': limit},
            )
            as List<dynamic>;
    return result;
  }

  /// Export a session as markdown or text.
  Future<String> sessionsExport(
    String sessionId, {
    String format = 'markdown',
  }) async {
    final result = await get(
      '/api/sessions/$sessionId/export',
      queryParameters: {'format': format},
    );
    return result.toString();
  }

  /// Delete empty sessions.
  Future<int> sessionsPrune() async {
    final result = await post('/api/sessions/prune');
    return (result as Map<String, dynamic>?)?['deleted'] as int? ?? 0;
  }

  /// Empty (clear) a session.
  Future<void> sessionsEmpty(String sessionId) async {
    await post('/api/sessions/$sessionId/empty');
  }

  /// Delete all empty sessions.
  Future<int> sessionsDeleteEmpty() async {
    final result = await post('/api/sessions/empty');
    return (result as Map<String, dynamic>?)?['deleted'] as int? ?? 0;
  }

  /// Bulk delete sessions.
  Future<int> sessionsBulkDelete(List<String> sessionIds) async {
    final result = await post(
      '/api/sessions/bulk-delete',
      data: {'session_ids': sessionIds},
    );
    return (result as Map<String, dynamic>?)?['deleted'] as int? ?? 0;
  }

  /// Rename a session.
  Future<void> sessionsRename(String sessionId, String title) async {
    await patch('/api/sessions/$sessionId', data: {'title': title});
  }

  /// Search sessions.
  Future<List<dynamic>> sessionsSearch(String query, {int? limit}) async {
    final result =
        await get(
              '/api/sessions/search',
              queryParameters: {
                'query': query,
                if (limit != null) 'limit': limit,
              },
            )
            as List<dynamic>;
    return result;
  }

  /// Get session stats.
  Future<Map<String, dynamic>> sessionsStats() async {
    return await get('/api/sessions/stats') as Map<String, dynamic>;
  }

  /// Count empty sessions.
  Future<int> sessionsEmptyCount() async {
    final result = await get('/api/sessions/empty/count');
    return (result as Map<String, dynamic>?)?['count'] as int? ?? 0;
  }

  /// PATCH request (for partial updates like rename).
  Future<dynamic> patch(String path, {dynamic data}) async {
    final headers = await _auth.authParams().then((a) => a.restHeaders);
    final resp = await _dio.patch(
      path,
      data: data,
      options: Options(headers: headers),
    );
    return _handleResponse(resp);
  }

  // ── Billing REST ──────────────────────────────────────────────────────────

  /// Get billing state (credits, packages, auto-reload).
  Future<Map<String, dynamic>> billingState() async {
    return await get('/api/billing/state') as Map<String, dynamic>;
  }

  /// Get available billing packages.
  Future<List<dynamic>> billingPackages() async {
    final result = await get('/api/billing/packages');
    return (result as List<dynamic>? ?? []);
  }

  /// Trigger a charge.
  Future<Map<String, dynamic>> billingCharge(String packageId) async {
    return await post('/api/billing/charge', data: {'package_id': packageId})
        as Map<String, dynamic>;
  }

  /// Get charge status.
  Future<Map<String, dynamic>> billingChargeStatus(String chargeId) async {
    return await get('/api/billing/charge/$chargeId/status')
        as Map<String, dynamic>;
  }

  /// Update auto-reload setting.
  Future<void> billingAutoReload({
    required bool enabled,
    double? threshold,
  }) async {
    await post(
      '/api/billing/auto-reload',
      data: {'enabled': enabled, if (threshold != null) 'threshold': threshold},
    );
  }
}
