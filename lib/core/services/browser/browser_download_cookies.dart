import 'dart:io' show InternetAddress;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Apple cookie queries return a domain-suffix search, not a request header.
/// Reapply request matching before handing credentials to the download client.
bool browserDownloadCookieMatches(Cookie cookie, Uri destination) {
  if (destination.scheme != 'http' && destination.scheme != 'https') {
    return false;
  }
  if (cookie.isSecure == true && destination.scheme != 'https') return false;
  final expires = cookie.expiresDate;
  if (cookie.isSessionOnly != true && expires != null) {
    // The Windows plugin forwards CDP's Unix seconds; Apple/Android use ms.
    final milliseconds = defaultTargetPlatform == TargetPlatform.windows
        ? expires * 1000
        : expires;
    if (milliseconds <= DateTime.now().millisecondsSinceEpoch) return false;
  }
  final domain = cookie.domain?.toLowerCase();
  if (domain == null || domain.isEmpty) {
    // Android's CookieManager.getCookie(url) already performs URL matching.
    // Older WebViews expose only the resulting name/value header, no metadata.
    return defaultTargetPlatform == TargetPlatform.android;
  }
  final host = destination.host.toLowerCase();
  final subdomains = domain.startsWith('.');
  final cookieHost = subdomains ? domain.substring(1) : domain;
  if (cookieHost.isEmpty ||
      (host != cookieHost &&
          !(subdomains &&
              InternetAddress.tryParse(host) == null &&
              host.endsWith('.$cookieHost')))) {
    return false;
  }
  final path = cookie.path;
  if (path == null || !path.startsWith('/')) return false;
  final requestPath = destination.path.isEmpty ? '/' : destination.path;
  return requestPath == path ||
      (requestPath.startsWith(path) &&
          (path.endsWith('/') || requestPath[path.length] == '/'));
}
