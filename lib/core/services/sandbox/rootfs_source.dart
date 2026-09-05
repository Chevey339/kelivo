/// Pinned Ubuntu Base image and hashes from the official release manifest:
/// https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/SHA256SUMS
/// Update the version and both hashes together.
const String kUbuntuBaseVersion = '24.04.3';
const String kUbuntuCodename = 'noble';
const String kUbuntuDistro = 'ubuntu';
const String kOfficialCdimageReleaseBase =
    'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release';
const String kTunaCdimageReleaseBase =
    'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release';
const String kHuaweiCdimageReleaseBase =
    'https://repo.huaweicloud.com/ubuntu-cdimage/ubuntu-base/releases/24.04/release';

enum RootfsDownloadSource { automatic, official, tuna, huawei, custom }

class RootfsSource {
  const RootfsSource({
    this.officialReleaseBase = kOfficialCdimageReleaseBase,
    this.cdimageReleaseBases = const [
      kOfficialCdimageReleaseBase,
      kTunaCdimageReleaseBase,
      kHuaweiCdimageReleaseBase,
    ],
    this.checksums = const {
      'arm64':
          '7b2dced6dd56ad5e4a813fa25c8de307b655fdabc6ea9213175a92c48dabb048',
      'amd64':
          '6bc2cde3930ad088b3bb46fa45279e96d25bc3810f209850ecbe4722711874f9',
    },
  });

  final String officialReleaseBase;
  final List<String> cdimageReleaseBases;
  final Map<String, String> checksums;

  static String? archForAbi(String abi) => switch (abi) {
    'arm64-v8a' || 'arm64' => 'arm64',
    'x86_64' || 'amd64' => 'amd64',
    _ => null,
  };

  static String tarballFileName(String arch) =>
      'ubuntu-base-$kUbuntuBaseVersion-base-$arch.tar.gz';

  Uri officialTarballUri(String arch) => tarballUri(officialReleaseBase, arch);

  Uri tarballUri(String releaseBase, String arch) => Uri.parse(
    '${releaseBase.replaceFirst(RegExp(r'/+$'), '')}/${tarballFileName(arch)}',
  );

  List<Uri> tarballCandidates(String arch) => [
    for (final base in cdimageReleaseBases) tarballUri(base, arch),
  ];

  /// A custom source may be a release directory or an exact archive URL.
  /// It always installs the pinned, checksum-verified image for this ABI.
  Uri? selectedUri(RootfsDownloadSource source, String customUrl, String arch) {
    return switch (source) {
      RootfsDownloadSource.automatic => null,
      RootfsDownloadSource.official => officialTarballUri(arch),
      RootfsDownloadSource.tuna => tarballUri(kTunaCdimageReleaseBase, arch),
      RootfsDownloadSource.huawei => tarballUri(
        kHuaweiCdimageReleaseBase,
        arch,
      ),
      RootfsDownloadSource.custom => customTarballUri(customUrl, arch),
    };
  }

  static Uri customTarballUri(String value, String arch) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        RegExp(r'\s').hasMatch(value.trim())) {
      throw const FormatException('Invalid download URL');
    }
    if (uri.path.endsWith('.tar.gz')) return uri;
    if (uri.hasQuery) throw const FormatException('Use a complete archive URL');
    return uri.replace(
      path:
          '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/${tarballFileName(arch)}',
    );
  }
}
