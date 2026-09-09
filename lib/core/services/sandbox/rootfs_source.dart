import 'rootfs_catalog.dart';
export 'rootfs_catalog.dart';

enum RootfsDownloadSource { automatic, official, tuna, huawei, custom, local }

class RootfsSource {
  const RootfsSource({
    this.image = RootfsCatalog.defaultImage,
    this.officialReleaseBase,
    this.cdimageReleaseBases,
    this.checksumOverrides,
  });

  final RootfsImage image;
  final String? officialReleaseBase;
  final List<String>? cdimageReleaseBases;
  final Map<String, String>? checksumOverrides;
  Map<String, String> get checksums => checksumOverrides ?? image.checksums;

  RootfsSource forImage(RootfsImage image) => RootfsSource(
    image: image,
    officialReleaseBase: officialReleaseBase,
    cdimageReleaseBases: cdimageReleaseBases,
    checksumOverrides: checksumOverrides,
  );

  static String? archForAbi(String abi) => switch (abi) {
    'armeabi-v7a' || 'armhf' => 'armhf',
    'arm64-v8a' || 'arm64' => 'arm64',
    'x86_64' || 'amd64' => 'amd64',
    _ => null,
  };

  List<RootfsDownloadSource> get availableSources => [
    RootfsDownloadSource.automatic,
    RootfsDownloadSource.official,
    if (image.distro != 'debian') ...[
      RootfsDownloadSource.tuna,
      RootfsDownloadSource.huawei,
    ],
    RootfsDownloadSource.custom,
    RootfsDownloadSource.local,
  ];

  String tarballFileName(String arch) => image.cacheName(arch);

  Uri officialTarballUri(String arch) => officialReleaseBase == null
      ? Uri.parse(image.urls[arch]!)
      : tarballUri(officialReleaseBase!, arch);

  Uri tarballUri(String releaseBase, String arch) => Uri.parse(
    '${releaseBase.replaceFirst(RegExp(r'/+$'), '')}/${image.fileName(arch)}',
  );

  List<Uri> tarballCandidates(String arch) => cdimageReleaseBases != null
      ? [for (final base in cdimageReleaseBases!) tarballUri(base, arch)]
      : [
          for (final source in availableSources)
            if (source == RootfsDownloadSource.official ||
                source == RootfsDownloadSource.tuna ||
                source == RootfsDownloadSource.huawei)
              selectedUri(source, '', arch)!,
        ];

  Uri? selectedUri(RootfsDownloadSource source, String customUrl, String arch) {
    if (!availableSources.contains(source)) {
      throw const FormatException(
        'Download source unavailable for this system',
      );
    }
    switch (source) {
      case RootfsDownloadSource.automatic:
      case RootfsDownloadSource.local:
        return null;
      case RootfsDownloadSource.official:
        return officialTarballUri(arch);
      case RootfsDownloadSource.custom:
        return customTarballUri(customUrl, arch, image: image);
      case RootfsDownloadSource.tuna:
      case RootfsDownloadSource.huawei:
        final host = source == RootfsDownloadSource.tuna
            ? 'mirrors.tuna.tsinghua.edu.cn'
            : 'repo.huaweicloud.com';
        final official = Uri.parse(image.urls[arch]!);
        return official.replace(
          host: host,
          path: image.distro == 'ubuntu'
              ? '/ubuntu-cdimage${official.path}'
              : official.path,
        );
    }
  }

  /// Custom mirrors must serve the selected, checksum-verified image.
  static Uri customTarballUri(
    String value,
    String arch, {
    RootfsImage image = RootfsCatalog.defaultImage,
  }) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        RegExp(r'\s').hasMatch(value.trim())) {
      throw const FormatException('Invalid download URL');
    }
    if (archiveFormat(uri.path) != null) return uri;
    if (uri.hasQuery) throw const FormatException('Use a complete archive URL');
    return uri.replace(
      path:
          '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/${image.fileName(arch)}',
    );
  }

  static String? archiveFormat(String path) {
    final name = path.toLowerCase();
    if (name.endsWith('.tar.gz') || name.endsWith('.tgz')) return 'tar.gz';
    if (name.endsWith('.tar.xz') || name.endsWith('.txz')) return 'tar.xz';
    if (name.endsWith('.tar')) return 'tar';
    return null;
  }
}
