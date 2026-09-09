import 'package:Kelivo/core/models/environment_state.dart';

class MirrorCandidate {
  const MirrorCandidate({
    required this.base,
    required this.probe,
    this.official = false,
  });

  final Uri base;
  final Uri probe;
  final bool official;
}

class MirrorCatalog {
  static const String defaultAlpineBranch = 'latest-stable';

  static Uri officialBase(MirrorCategory category, {String arch = 'arm64'}) {
    return candidates(category, arch: arch).firstWhere((c) => c.official).base;
  }

  static List<MirrorCandidate> candidates(
    MirrorCategory category, {
    String arch = 'arm64',
  }) {
    switch (category) {
      case MirrorCategory.apt:
        return arch == 'amd64' ? _aptAmd64 : _aptArm64;
      case MirrorCategory.apk:
        return _apk;
      case MirrorCategory.pip:
        return _pip;
      case MirrorCategory.npm:
        return _npm;
    }
  }

  static final List<MirrorCandidate> _aptArm64 = [
    _apt('http://ports.ubuntu.com/ubuntu-ports', official: true),
    _apt('https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports'),
    _apt('https://mirrors.ustc.edu.cn/ubuntu-ports'),
    _apt('https://mirrors.aliyun.com/ubuntu-ports'),
    _apt('https://mirrors.cloud.tencent.com/ubuntu-ports'),
    _apt('https://repo.huaweicloud.com/ubuntu-ports'),
  ];

  static final List<MirrorCandidate> _aptAmd64 = [
    _apt('http://archive.ubuntu.com/ubuntu', official: true),
    _apt('https://mirrors.tuna.tsinghua.edu.cn/ubuntu'),
    _apt('https://mirrors.ustc.edu.cn/ubuntu'),
    _apt('https://mirrors.aliyun.com/ubuntu'),
    _apt('https://mirrors.cloud.tencent.com/ubuntu'),
    _apt('https://repo.huaweicloud.com/ubuntu'),
  ];

  static final List<MirrorCandidate> _apk = [
    _entry(
      'https://dl-cdn.alpinelinux.org/alpine',
      'last-updated',
      official: true,
    ),
    _entry('https://mirrors.tuna.tsinghua.edu.cn/alpine', 'last-updated'),
    _entry('https://mirrors.ustc.edu.cn/alpine', 'last-updated'),
    _entry('https://mirrors.aliyun.com/alpine', 'last-updated'),
  ];

  static final List<MirrorCandidate> _pip = [
    _entry('https://pypi.org/simple', 'pip/', official: true),
    _entry('https://pypi.tuna.tsinghua.edu.cn/simple', 'pip/'),
    _entry('https://mirrors.aliyun.com/pypi/simple', 'pip/'),
    _entry('https://pypi.mirrors.ustc.edu.cn/simple', 'pip/'),
    _entry('https://mirrors.cloud.tencent.com/pypi/simple', 'pip/'),
  ];

  static final List<MirrorCandidate> _npm = [
    _entry('https://registry.npmjs.org', '-/ping', official: true),
    _entry('https://registry.npmmirror.com', '-/ping'),
  ];

  static MirrorCandidate _apt(String base, {bool official = false}) {
    return _entry(base, 'dists/noble/Release', official: official);
  }

  static MirrorCandidate _entry(
    String base,
    String probePath, {
    bool official = false,
  }) {
    final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
    return MirrorCandidate(
      base: Uri.parse(_trimSlash(base)),
      probe: baseUri.resolve(probePath),
      official: official,
    );
  }

  static String _trimSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}
