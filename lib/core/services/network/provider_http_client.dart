import 'package:dio/dio.dart' show CancelToken;
import 'package:http/http.dart' as http;

import '../../providers/settings_provider.dart';
import 'dio_http_client.dart';

/// HTTP client for requests to [config]'s endpoint, routed through the
/// provider's proxy when one is configured.
http.Client providerHttpClient(
  ProviderConfig config, {
  CancelToken? cancelToken,
}) {
  final host = (config.proxyHost ?? '').trim();
  final port = (config.proxyPort ?? '').trim();
  if (config.proxyEnabled == true && host.isNotEmpty && port.isNotEmpty) {
    final user = (config.proxyUsername ?? '').trim();
    final pass = (config.proxyPassword ?? '').trim();
    return DioHttpClient(
      proxy: NetworkProxyConfig(
        enabled: true,
        type: ProviderConfig.resolveProxyType(config.proxyType),
        host: host,
        port: int.tryParse(port) ?? 8080,
        username: user.isEmpty ? null : user,
        password: pass.isEmpty ? null : pass,
      ),
      cancelToken: cancelToken,
    );
  }
  return DioHttpClient(cancelToken: cancelToken);
}
