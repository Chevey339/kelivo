import 'package:flutter/foundation.dart' show visibleForTesting;

class GuestScripts {
  static final RegExp _unsafeChars = RegExp(r'''[\s'"\\`$()]''');
  static final RegExp _host = RegExp(r'^[A-Za-z0-9.-]+$');
  static final RegExp _token = RegExp(r'^[A-Za-z0-9._-]+$');

  static String applyAptMirror(
    String base,
    String arch, {
    String distro = 'ubuntu',
    String codename = 'noble',
  }) {
    final url = _validatedHttpUrl(base);
    _requireToken(arch, 'arch');
    _requireToken(codename, 'codename');
    // Ubuntu 22.04 and older/local Debian images use the legacy main list.
    // Keep a backup so adding a deb822 source does not leave both active.
    const legacy =
        'set -e\n'
        'if [ -f /etc/apt/sources.list ]; then\n'
        '  mv /etc/apt/sources.list /etc/apt/sources.list.kelivo-bak\n'
        'fi\n';
    if (distro == 'debian') {
      final security = Uri.parse(
        url.endsWith('/') ? url : '$url/',
      ).resolve('../debian-security/');
      return legacy +
          writeFile(
            path: '/etc/apt/sources.list.d/debian.sources',
            body:
                'Types: deb\nURIs: $url\nSuites: $codename $codename-updates\n'
                'Components: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n\n'
                'Types: deb\nURIs: $security\nSuites: $codename-security\n'
                'Components: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n',
          );
    }
    return legacy +
        writeFile(
          path: '/etc/apt/sources.list.d/ubuntu.sources',
          body:
              'Types: deb\n'
              'URIs: $url\n'
              'Suites: $codename $codename-updates $codename-security\n'
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
