import '../../providers/settings_provider.dart';

/// Proxy defaults for programs that support the standard proxy environment.
/// Explicit guest variables win, including uppercase spellings. These are
/// process-local defaults, never persisted into the guest's shell profile.
Map<String, String> sandboxProxyEnvironment(
  SettingsProvider settings,
  Map<String, String> variables,
) {
  final host = settings.globalProxyHost.trim();
  final port = int.tryParse(settings.globalProxyPort.trim());
  if (!settings.globalProxyEnabled ||
      host.isEmpty ||
      port == null ||
      port < 1 ||
      port > 65535) {
    return variables;
  }

  final username = settings.globalProxyUsername.trim();
  final userInfo = username.isEmpty
      ? ''
      : '${Uri.encodeComponent(username)}:'
            '${Uri.encodeComponent(settings.globalProxyPassword)}';
  // Match the app's HTTP/HTTPS proxy choices: both use a plain HTTP proxy
  // with CONNECT for HTTPS destinations. SOCKS resolves names at the proxy.
  final String proxy;
  try {
    proxy = Uri(
      scheme: settings.globalProxyType == 'socks5' ? 'socks5h' : 'http',
      userInfo: userInfo,
      host: host,
      port: port,
    ).toString();
  } on FormatException {
    // The host field is saved on blur, including partially entered addresses.
    // An invalid proxy must not prevent local shell or file tools from running.
    return variables;
  }
  // Each guest client owns no_proxy matching (domain suffixes, CIDR support).
  final bypass = settings.globalProxyBypass
      .split(RegExp(r'[,;\s]+'))
      .where((rule) => rule.isNotEmpty)
      .map((rule) => rule.startsWith('*.') ? rule.substring(1) : rule)
      // no_proxy has no portable support for arbitrary wildcard patterns.
      .where((rule) => rule == '*' || !rule.contains('*'))
      .join(',');
  final result = <String, String>{};
  final allProxy = variables['all_proxy'] ?? variables['ALL_PROXY'] ?? proxy;
  for (final (lower, upper, fallback) in [
    ('http_proxy', 'HTTP_PROXY', allProxy),
    ('https_proxy', 'HTTPS_PROXY', allProxy),
    ('all_proxy', 'ALL_PROXY', allProxy),
    ('no_proxy', 'NO_PROXY', bypass),
  ]) {
    final value = variables[lower] ?? variables[upper] ?? fallback;
    result[lower] = value;
    // curl deliberately ignores HTTP_PROXY because CGI can populate it from
    // a request header. There is no need to introduce that spelling ourselves.
    if (upper != 'HTTP_PROXY') result[upper] = value;
  }
  return {...result, ...variables};
}
