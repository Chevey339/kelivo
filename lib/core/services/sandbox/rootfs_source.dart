import 'package:http/http.dart' as http;

/// Pinned Ubuntu Base point release. Both 24.04.3 and 24.04.4 are listed on
/// the official SHA256SUMS; 24.04.3 is the requested pin and the file exists.
const String kUbuntuBaseVersion = '24.04.3';
const String kUbuntuCodename = 'noble';
const String kUbuntuDistro = 'ubuntu';

const String kOfficialCdimageReleaseBase =
    'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release';

/// Tsinghua TUNA — SHA256SUMS GET 200 (2026-09-03).
const String kTunaCdimageReleaseBase =
    'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release';

/// Huawei Cloud repo — SHA256SUMS Range GET 206 (2026-09-03).
const String kHuaweiCdimageReleaseBase =
    'https://repo.huaweicloud.com/ubuntu-cdimage/ubuntu-base/releases/24.04/release';

class RootfsSource {
  RootfsSource({
    http.Client? client,
    this.officialReleaseBase = kOfficialCdimageReleaseBase,
    List<String>? cdimageReleaseBases,
  }) : _client = client ?? http.Client(),
       cdimageReleaseBases =
           cdimageReleaseBases ??
           const <String>[
             kOfficialCdimageReleaseBase,
             kTunaCdimageReleaseBase,
             kHuaweiCdimageReleaseBase,
           ];

  final http.Client _client;
  final String officialReleaseBase;
  final List<String> cdimageReleaseBases;

  static String? archForAbi(String abi) {
    switch (abi) {
      case 'arm64-v8a':
      case 'arm64':
        return 'arm64';
      case 'x86_64':
      case 'amd64':
        return 'amd64';
      default:
        return null;
    }
  }

  static String tarballFileName(String arch) =>
      'ubuntu-base-$kUbuntuBaseVersion-base-$arch.tar.gz';

  Uri officialSha256SumsUri() => sha256SumsUri(officialReleaseBase);

  Uri officialTarballUri(String arch) => tarballUri(officialReleaseBase, arch);

  Uri sha256SumsUri(String releaseBase) =>
      Uri.parse('${_trimSlash(releaseBase)}/SHA256SUMS');

  Uri tarballUri(String releaseBase, String arch) =>
      Uri.parse('${_trimSlash(releaseBase)}/${tarballFileName(arch)}');

  List<Uri> tarballCandidates(String arch) => [
    for (final base in cdimageReleaseBases) tarballUri(base, arch),
  ];

  List<Uri> sha256SumsCandidates() => [
    for (final base in cdimageReleaseBases) sha256SumsUri(base),
  ];

  String releaseBaseForUri(Uri uri) {
    final text = uri.toString();
    for (final base in cdimageReleaseBases) {
      if (text.startsWith(_trimSlash(base))) return base;
    }
    return officialReleaseBase;
  }

  /// Always reads SHA256SUMS from the official host, never a mirror.
  Future<String> fetchExpectedSha256(String arch) async {
    final response = await _client.get(officialSha256SumsUri());
    if (response.statusCode != 200) {
      throw StateError(
        'SHA256SUMS HTTP ${response.statusCode} from official host',
      );
    }
    final digest = parseSha256Sums(response.body, tarballFileName(arch));
    if (digest == null) {
      throw StateError('SHA256SUMS has no entry for ${tarballFileName(arch)}');
    }
    return digest;
  }

  static String? parseSha256Sums(String body, String fileName) {
    for (final rawLine in body.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final match = _sha256Line.firstMatch(line);
      if (match == null) continue;
      if (match.group(2) == fileName) {
        return match.group(1)!.toLowerCase();
      }
    }
    return null;
  }

  static final RegExp _sha256Line = RegExp(
    r'^([0-9a-fA-F]{64})\s+\*?(\S+)\s*$',
  );

  static String _trimSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}
