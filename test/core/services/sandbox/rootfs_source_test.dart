import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';

void main() {
  const source = RootfsSource();
  test('ABI map and pinned hashes match the official 24.04.3 manifest', () {
    expect(RootfsSource.archForAbi('arm64-v8a'), 'arm64');
    expect(RootfsSource.archForAbi('x86_64'), 'amd64');
    expect(RootfsSource.archForAbi('armeabi-v7a'), isNull);
    expect(
      source.checksums['arm64'],
      '7b2dced6dd56ad5e4a813fa25c8de307b655fdabc6ea9213175a92c48dabb048',
    );
    expect(
      source.checksums['amd64'],
      '6bc2cde3930ad088b3bb46fa45279e96d25bc3810f209850ecbe4722711874f9',
    );
  });
  test('automatic probes, explicit sources resolve without choosing again', () {
    expect(
      source.selectedUri(RootfsDownloadSource.automatic, '', 'arm64'),
      isNull,
    );
    expect(
      source.selectedUri(RootfsDownloadSource.official, '', 'arm64'),
      source.officialTarballUri('arm64'),
    );
    expect(
      source.selectedUri(RootfsDownloadSource.tuna, '', 'amd64').toString(),
      '$kTunaCdimageReleaseBase/ubuntu-base-24.04.3-base-amd64.tar.gz',
    );
    expect(
      source.selectedUri(RootfsDownloadSource.huawei, '', 'arm64').toString(),
      '$kHuaweiCdimageReleaseBase/ubuntu-base-24.04.3-base-arm64.tar.gz',
    );
  });
  test('custom directory follows ABI, full URLs preserve query parameters', () {
    expect(
      RootfsSource.customTarballUri(
        ' https://mirror.test/release/ ',
        'amd64',
      ).toString(),
      'https://mirror.test/release/ubuntu-base-24.04.3-base-amd64.tar.gz',
    );
    expect(
      RootfsSource.customTarballUri(
        'https://mirror.test/image.tar.gz?token=x%2Fy',
        'arm64',
      ).toString(),
      'https://mirror.test/image.tar.gz?token=x%2Fy',
    );
  });
  test('reject malformed, credential-bearing and non-HTTP custom sources', () {
    for (final url in [
      '',
      'file:///tmp/a.tar.gz',
      'ftp://mirror.test/',
      'https://user:pass@mirror.test/',
      'https://mirror.test/with space',
      'https://mirror.test/#part',
      'https://mirror.test/release?token=x',
    ]) {
      expect(
        () => RootfsSource.customTarballUri(url, 'arm64'),
        throwsFormatException,
        reason: url,
      );
    }
  });
}
