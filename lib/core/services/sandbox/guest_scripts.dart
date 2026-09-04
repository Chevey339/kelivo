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

  static String restoreAptMirror() => restore(
    '/etc/apt/sources.list.d/ubuntu.sources',
    officialBody:
        'Types: deb\n'
        'URIs: http://ports.ubuntu.com/ubuntu-ports/\n'
        'Suites: noble noble-updates noble-security\n'
        'Components: main universe\n'
        'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n',
  );

  static String restoreApkMirror({String alpineBranch = 'v3.21'}) {
    _requireToken(alpineBranch, 'alpineBranch');
    return restore(
      '/etc/apk/repositories',
      officialBody:
          'https://dl-cdn.alpinelinux.org/alpine/$alpineBranch/main\n'
          'https://dl-cdn.alpinelinux.org/alpine/$alpineBranch/community\n',
    );
  }

  static String restorePipMirror() => restore(
    '/etc/pip.conf',
    officialBody:
        '[global]\n'
        'index-url = https://pypi.org/simple/\n'
        'trusted-host = pypi.org\n',
  );

  static String restoreNpmMirror() => restore(
    '/root/.npmrc',
    officialBody: 'registry=https://registry.npmjs.org/\n',
  );

  /// Writes [body] to [path], backing up an existing original only once.
  @visibleForTesting
  static String writeFile({required String path, required String body}) {
    return 'set -e\n'
        'mkdir -p "\$(dirname $path)"\n'
        'if [ -f $path ] && [ ! -f $path.bak ] && [ ! -f $path.kelivo-created ]; then\n'
        '  cp $path $path.bak\n'
        'fi\n'
        'if [ ! -f $path ]; then\n'
        '  touch $path.kelivo-created\n'
        'fi\n'
        "cat > $path <<'EOF'\n"
        '$body'
        'EOF\n';
  }

  /// Restores [path] from `.bak`, or removes a file we created from scratch.
  ///
  /// Uses `cat > dest` instead of `mv` so iSH's 9p fakefs can replace an
  /// existing file. When neither `.bak` nor the sentinel exists, writes
  /// [officialBody] so a missing backup still returns the guest to official.
  @visibleForTesting
  static String restore(String path, {String? officialBody}) {
    final fallback = officialBody == null || officialBody.isEmpty
        ? ''
        : 'else\n'
              "cat > $path <<'EOF'\n"
              '$officialBody'
              'EOF\n';
    return 'set -e\n'
        'if [ -f $path.bak ]; then\n'
        '  cat $path.bak > $path\n'
        '  rm -f $path.bak $path.kelivo-created\n'
        'elif [ -f $path.kelivo-created ]; then\n'
        '  rm -f $path $path.kelivo-created\n'
        '$fallback'
        'fi\n';
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
