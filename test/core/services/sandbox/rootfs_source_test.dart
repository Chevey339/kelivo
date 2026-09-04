import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';

void main() {
  test('ABI map', () {
    expect(RootfsSource.archForAbi('arm64-v8a'), 'arm64');
    expect(RootfsSource.archForAbi('x86_64'), 'amd64');
    expect(RootfsSource.archForAbi('armeabi-v7a'), isNull);
    expect(RootfsSource.archForAbi('x86'), isNull);
  });

  test('tarball and SHA256SUMS URL construction', () {
    final catalog = RootfsSource();
    expect(
      catalog.officialTarballUri('arm64').toString(),
      'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-arm64.tar.gz',
    );
    expect(
      catalog.officialSha256SumsUri().toString(),
      'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/SHA256SUMS',
    );
    expect(
      catalog.tarballUri(kTunaCdimageReleaseBase, 'amd64').toString(),
      'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-amd64.tar.gz',
    );
  });

  test('SHA256SUMS parsing accepts star and two-space forms', () {
    const body = '''
7b2dced6dd56ad5e4a813fa25c8de307b655fdabc6ea9213175a92c48dabb048 *ubuntu-base-24.04.3-base-arm64.tar.gz
6bc2cde3930ad088b3bb46fa45279e96d25bc3810f209850ecbe4722711874f9  ubuntu-base-24.04.3-base-amd64.tar.gz
''';
    expect(
      RootfsSource.parseSha256Sums(body, RootfsSource.tarballFileName('arm64')),
      '7b2dced6dd56ad5e4a813fa25c8de307b655fdabc6ea9213175a92c48dabb048',
    );
    expect(
      RootfsSource.parseSha256Sums(body, RootfsSource.tarballFileName('amd64')),
      '6bc2cde3930ad088b3bb46fa45279e96d25bc3810f209850ecbe4722711874f9',
    );
    expect(RootfsSource.parseSha256Sums(body, 'missing.tar.gz'), isNull);
  });

  test('fetchExpectedSha256 reads official host only', () async {
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      expect(
        request.url.host,
        'cdimage.ubuntu.com',
        reason: 'SHA256SUMS must come from the official host',
      );
      return http.Response(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *ubuntu-base-24.04.3-base-arm64.tar.gz\n',
        200,
      );
    });
    final source = RootfsSource(client: client);
    expect(await source.fetchExpectedSha256('arm64'), 'a' * 64);
    expect(requested, [source.officialSha256SumsUri()]);
  });
}
