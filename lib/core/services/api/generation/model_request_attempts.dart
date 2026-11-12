import 'dart:async';

import 'package:http/http.dart' as http;

/// A text-generation invocation normally sends once. Authentication recovery
/// can resend below the provider loop, so compression also accounts for those
/// additional requests before they reach the network.
class ModelRequestAttempts {
  ModelRequestAttempts._(this.onAdditionalAttempt);
  final Future<void> Function() onAdditionalAttempt;
  var _sent = 0;
  static final _key = Object();

  static Future<T> run<T>({
    required Future<T> Function() action,
    required Future<void> Function() onAdditionalAttempt,
  }) => runZoned(
    action,
    zoneValues: {_key: ModelRequestAttempts._(onAdditionalAttempt)},
  );

  static http.Client wrap(http.Client client) {
    final scope = Zone.current[_key] as ModelRequestAttempts?;
    return scope == null ? client : _AttemptClient(client, scope);
  }
}

class _AttemptClient extends http.BaseClient {
  _AttemptClient(this.inner, this.scope);
  final http.Client inner;
  final ModelRequestAttempts scope;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' && scope._sent++ > 0) {
      await scope.onAdditionalAttempt();
    }
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}
