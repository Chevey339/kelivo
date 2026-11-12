import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Exercise the certificate boundary without accessing a real keychain or
// requiring an Apple certificate. OpenSSL deliberately cannot decode PKCS#12;
// macOS security is the authority for importing and validating the identity.
const _importCertificate = r'''
source "$SIGNING_SCRIPT" --help >/dev/null

openssl() {
  if [[ "$1" != "rand" ]]; then
    echo 'unsupported: RC2-40-CBC' >&2
    return 1
  fi
  printf 'temporary-keychain-password\n'
}

base64() {
  command base64 "$DECODE_FLAG"
}

curl() { return 1; }

security() {
  local cmd="$1"
  shift
  printf '%s\n' "$cmd" >>"$CALL_LOG"
  case "$cmd" in
    list-keychains)
      if [[ "$*" == '-d user' ]]; then
        printf '    "/tmp/existing.keychain-db"\n'
      fi
      ;;
    default-keychain)
      if [[ $# -eq 0 ]]; then
        printf '    "/tmp/existing.keychain-db"\n'
      fi
      ;;
    import)
      [[ "$(cat "$1")" == 'fixture-certificate' ]] || return 2
      [[ "$REJECT_IMPORT" == 'false' ]] || return 1
      ;;
    find-identity)
      if [[ "$HAS_IDENTITY" == 'true' ]]; then
        printf '1) ABCDEF "Developer ID Application: Fixture (5WN7Y88J52)"\n'
      fi
      ;;
    create-keychain | set-keychain-settings | unlock-keychain | set-key-partition-list | delete-keychain)
      ;;
    *) return 2 ;;
  esac
}

start_secure_workspace
import_certificate
printf 'import succeeded\n'
''';

void main() {
  group('macOS signing certificate import', () {
    late Directory temp;
    late File calls;
    late Map<String, String> environment;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('kelivo_signing_test_');
      calls = File('${temp.path}/calls.txt');
      environment = {
        'PATH': '/usr/bin:/bin',
        'SIGNING_SCRIPT': File('tool/macos_sign_and_notarize.sh').absolute.path,
        'RUNNER_TEMP': temp.path,
        'CALL_LOG': calls.path,
        'DECODE_FLAG': Platform.isMacOS ? '-D' : '--decode',
        'MACOS_CERTIFICATE_P12_BASE64': base64Encode(
          utf8.encode('fixture-certificate'),
        ),
        'MACOS_CERTIFICATE_PASSWORD': 'fixture-password',
        'REJECT_IMPORT': 'false',
        'HAS_IDENTITY': 'true',
      };
    });

    tearDown(() => temp.delete(recursive: true));

    Future<ProcessResult> runImport() => Process.run(
      '/bin/bash',
      ['-c', _importCertificate],
      environment: environment,
      includeParentEnvironment: false,
    );

    Future<void> expectCleanup() async {
      expect(await calls.readAsLines(), contains('delete-keychain'));
      expect(
        await temp.list().where((entry) => entry is Directory).isEmpty,
        true,
      );
    }

    test('accepts a native identity when OpenSSL rejects PKCS#12', () async {
      final result = await runImport();
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('import succeeded'));
      expect(
        await calls.readAsLines(),
        containsAll(['import', 'find-identity']),
      );
      await expectCleanup();
    });

    test('fails when native certificate import rejects the password', () async {
      environment['REJECT_IMPORT'] = 'true';
      final result = await runImport();
      expect(result.exitCode, isNot(0));
      expect(await calls.readAsLines(), contains('import'));
      expect(result.stdout, isNot(contains('import succeeded')));
      expect(result.stderr, isNot(contains('fixture-password')));
      await expectCleanup();
    });

    test('fails when the certificate has no valid signing identity', () async {
      environment['HAS_IDENTITY'] = 'false';
      final result = await runImport();
      expect(result.exitCode, isNot(0));
      expect(await calls.readAsLines(), contains('find-identity'));
      expect(result.stdout, isNot(contains('import succeeded')));
      await expectCleanup();
    });
  }, skip: !(Platform.isMacOS || Platform.isLinux));
}
