import 'package:flutter/foundation.dart' show visibleForTesting;

class GuestScripts {
  static final RegExp _unsafeChars = RegExp(r'''[\s'"\\`$()]''');
  static final RegExp _host = RegExp(r'^[A-Za-z0-9.-]+$');
  static final RegExp _token = RegExp(r'^[A-Za-z0-9._-]+$');

  static String applyAptMirror(String base, String arch) {
    final url = _validatedHttpUrl(base);
    _requireToken(arch, 'arch');
    return writeFile(
      path: '/etc/apt/sources.list.d/ubuntu.sources',
      body:
          'Types: deb\n'
          'URIs: $url\n'
          'Suites: noble noble-updates noble-security\n'
          'Components: main universe\n'
          'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n',
    );
  }

  static String applyApkMirror(String base, String alpineBranch) {
    final url = _validatedHttpUrl(base);
    _requireToken(alpineBranch, 'alpineBranch');
    return writeFile(
      path: '/etc/apk/repositories',
      body:
          '$url/$alpineBranch/main\n'
          '$url/$alpineBranch/community\n',
    );
  }

  static String applyPipMirror(String base) {
    final uri = _validatedUri(base);
    return writeFile(
      path: '/etc/pip.conf',
      body:
          '[global]\n'
          'index-url = $uri\n'
          'trusted-host = ${uri.host}\n',
    );
  }

  static String applyNpmMirror(String base) {
    final url = _validatedHttpUrl(base);
    return writeFile(path: '/root/.npmrc', body: 'registry=$url\n');
  }

  /// Replaces the selected source in place, including on iSH fakefs.
  @visibleForTesting
  static String writeFile({required String path, required String body}) {
    return 'set -e\n'
        'mkdir -p "\$(dirname $path)"\n'
        "cat > $path <<'EOF'\n"
        '$body'
        'EOF\n';
  }

  static String _validatedHttpUrl(String base) =>
      _validatedUri(base).toString();

  static Uri _validatedUri(String base) {
    if (base.contains('\$(') || _unsafeChars.hasMatch(base)) {
      throw ArgumentError.value(base, 'base', 'unsafe mirror URL');
    }
    final uri = Uri.tryParse(base);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !_host.hasMatch(uri.host)) {
      throw ArgumentError.value(base, 'base', 'must be http(s):// with a host');
    }
    return uri;
  }

  static void _requireToken(String value, String name) {
    if (!_token.hasMatch(value)) {
      throw ArgumentError.value(value, name, 'invalid token');
    }
  }
}
