/// Hermes auth implementations.
///
/// Two modes are supported:
/// - **Loopback** (`LoopbackAuth`): Static token passed as `?token=<X-Hermes-Session-Token>`
/// - **Gated** (`GatedAuth`): One-time ticket obtained via `POST /api/auth/ws-ticket`
///
/// Both implement the same interface so [HermesGateway] can switch mode at runtime.

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

/// Query params or headers injected into WS / REST requests for auth.
class WsAuthParams {
  /// Query parameters to append to the WebSocket URL.
  final Map<String, String> wsQueryParams;

  /// HTTP headers for REST API calls.
  final Map<String, String> restHeaders;

  const WsAuthParams({
    this.wsQueryParams = const {},
    this.restHeaders = const {},
  });
}

/// Abstract auth handler consumed by [HermesGateway] and [HermesRestClient].
abstract class HermesAuth {
  /// Returns query params for the WebSocket URL (e.g. `?token=xxx`).
  Future<WsAuthParams> authParams();

  /// The current static token, if available (used for display / storage).
  String? get currentToken;
}

/// Loopback / insecure auth: static token used directly.
class LoopbackAuth implements HermesAuth {
  final String token;

  const LoopbackAuth(this.token);

  @override
  Future<WsAuthParams> authParams() async {
    return WsAuthParams(
      wsQueryParams: {'token': token},
      restHeaders: {'Authorization': 'Bearer $token'},
    );
  }

  @override
  String? get currentToken => token;
}

/// Gated / OAuth auth: ticket obtained from `/api/auth/ws-ticket`.
class GatedAuth implements HermesAuth {
  final String baseUrl;
  final http.Client _httpClient;

  String? _cachedTicket;
  DateTime? _ticketExpiry;

  GatedAuth({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Obtain a fresh one-time ticket, caching it for up to 25 seconds.
  Future<String> _fetchTicket() async {
    if (_cachedTicket != null &&
        _ticketExpiry != null &&
        DateTime.now().isBefore(_ticketExpiry!)) {
      return _cachedTicket!;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/auth/ws-ticket');
      final resp = await _httpClient
          .post(uri)
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        throw HermesAuthException(
          'Failed to obtain WS ticket: HTTP ${resp.statusCode}',
        );
      }

      final body = resp.body;
      // Hermes returns `{"ticket": "..."}`
      final ticket = (body.contains('"ticket"'))
          ? body.split('"ticket"')[1].split('"')[1]
          : body.trim();

      _cachedTicket = ticket;
      _ticketExpiry = DateTime.now().add(const Duration(seconds: 25));
      return ticket;
    } on DioException catch (e) {
      throw HermesAuthException('Network error fetching ticket: $e');
    }
  }

  @override
  Future<WsAuthParams> authParams() async {
    final ticket = await _fetchTicket();
    return WsAuthParams(
      wsQueryParams: {'ticket': ticket},
      restHeaders: const {'credentials': 'include'},
    );
  }

  @override
  String? get currentToken => null;

  /// Invalidate cached ticket (call on 401).
  void invalidateTicket() {
    _cachedTicket = null;
    _ticketExpiry = null;
  }
}

/// Raised when auth fails.
class HermesAuthException implements Exception {
  final String message;
  const HermesAuthException(this.message);

  @override
  String toString() => 'HermesAuthException: $message';
}
