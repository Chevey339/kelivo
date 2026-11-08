import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/provider_oauth.dart';
import '../network/dio_http_client.dart';
import '../network/provider_http_exception.dart';
import 'oauth_callback_types.dart';

/// Only classifications cross the OAuth boundary. Transport messages, URLs,
/// headers and response bodies can contain credentials and are never copied.
ProviderOAuthException oauthFailure(Object error) {
  if (error is ProviderOAuthException) return error;
  if (error is TransportClientException) return oauthFailure(error.cause);
  if (error is ProviderHttpException && error.bodyReadError != null) {
    return oauthFailure(error.bodyReadError!);
  }
  if (error is OAuthCallbackException) {
    return ProviderOAuthException(
      error.cancelled
          ? ProviderOAuthFailure.cancelled
          : ProviderOAuthFailure.invalidResponse,
    );
  }
  var reason = ProviderOAuthTransportFailure.unknown;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.cancel:
        return const ProviderOAuthException(ProviderOAuthFailure.cancelled);
      case DioExceptionType.badResponse:
        return ProviderOAuthException(
          ProviderOAuthFailure.requestRejected,
          statusCode: error.response?.statusCode,
        );
      case DioExceptionType.connectionTimeout:
        reason = ProviderOAuthTransportFailure.connectionTimeout;
      case DioExceptionType.sendTimeout:
        reason = ProviderOAuthTransportFailure.sendTimeout;
      case DioExceptionType.receiveTimeout:
        reason = ProviderOAuthTransportFailure.receiveTimeout;
      case DioExceptionType.badCertificate:
        reason = ProviderOAuthTransportFailure.tls;
      case DioExceptionType.connectionError:
        if (error.error case final cause?) {
          final failure = oauthFailure(cause);
          if (failure.transportFailure !=
              ProviderOAuthTransportFailure.unknown) {
            return failure;
          }
        }
        reason = ProviderOAuthTransportFailure.connection;
      case DioExceptionType.unknown:
        if (error.error case final cause?) return oauthFailure(cause);
    }
  } else if (error is TimeoutException) {
    reason = ProviderOAuthTransportFailure.requestTimeout;
  } else if (error is TlsException) {
    reason = ProviderOAuthTransportFailure.tls;
  } else if (error is SocketException) {
    // Dart exposes DNS lookup failures as SocketException, without a DNS type.
    final message = error.message.toLowerCase();
    reason =
        [
          'failed host lookup',
          'name or service not known',
          'nodename nor servname provided',
          'temporary failure in name resolution',
          'no address associated with hostname',
        ].any(message.contains)
        ? ProviderOAuthTransportFailure.dns
        : message.contains('timed out')
        ? ProviderOAuthTransportFailure.requestTimeout
        : ProviderOAuthTransportFailure.connection;
  } else if (error is HttpException &&
      error.message.toLowerCase().startsWith(
        'proxy failed to establish tunnel',
      )) {
    reason = ProviderOAuthTransportFailure.proxy;
  }
  return ProviderOAuthException(switch (reason) {
    ProviderOAuthTransportFailure.connectionTimeout ||
    ProviderOAuthTransportFailure.sendTimeout ||
    ProviderOAuthTransportFailure.receiveTimeout ||
    ProviderOAuthTransportFailure.requestTimeout =>
      ProviderOAuthFailure.timeout,
    _ => ProviderOAuthFailure.network,
  }, transportFailure: reason);
}

Future<T> oauthAtStage<T>(
  ProviderOAuthStage stage,
  Future<T> Function() operation,
) async {
  try {
    return await operation();
  } catch (error) {
    throw oauthFailure(error).atStage(stage);
  }
}
