/// Pinned rootfs archives verified against the publishers' SHA-256 manifests.
/// Ubuntu: https://cdimage.ubuntu.com/ubuntu-base/releases/
/// Alpine: https://dl-cdn.alpinelinux.org/alpine/
/// Debian: https://github.com/debuerreotype/docker-debian-artifacts
class RootfsImage {
  const RootfsImage({
    required this.id,
    required this.distro,
    required this.version,
    required this.codename,
    required this.urls,
    required this.checksums,
  });

  final String id;
  final String distro;
  final String version;
  final String codename;
  final Map<String, String> urls;
  final Map<String, String> checksums;
  String get label => '${distroName(distro)} $version';
  String get format => distro == 'debian' ? 'tar.xz' : 'tar.gz';
  int get minFreeBytes => (distro == 'alpine' ? 64 : 600) * 1024 * 1024;
  String fileName(String arch) => Uri.parse(urls[arch]!).pathSegments.last;
  // Debian publishes the same archive filename for every release.
  String cacheName(String arch) => '$id-$arch.$format';

  static String distroName(String distro) => switch (distro) {
    'ubuntu' => 'Ubuntu',
    'alpine' => 'Alpine Linux',
    'debian' => 'Debian',
    _ => distro,
  };
}

abstract final class RootfsCatalog {
  static const defaultImage = ubuntu24043;
  // Keep each distribution newest-first for update checks. The default
  // installation is pinned independently of newly added releases.
  static const images = [
    ubuntu24044,
    ubuntu24043,
    ubuntu2204,
    alpine324,
    alpine323,
    alpine322,
    debian13,
    debian12,
  ];

  static RootfsImage byId(String id) =>
      images.firstWhere((image) => image.id == id);
  static List<RootfsImage> forDistro(String distro) =>
      images.where((image) => image.distro == distro).toList();
  static RootfsImage defaultForDistro(String distro) =>
      distro == defaultImage.distro ? defaultImage : forDistro(distro).first;

  static const ubuntu24044 = RootfsImage(
    id: 'ubuntu-24.04.4',
    distro: 'ubuntu',
    version: '24.04.4',
    codename: 'noble',
    urls: {
      'armhf':
          'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-armhf.tar.gz',
      'arm64':
          'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz',
      'amd64':
          'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-amd64.tar.gz',
    },
    checksums: {
      'armhf':
          '991520b47f6586f38a78505cf016e300b6191bb8ff86a0723481ec23a37ab7f4',
      'arm64':
          '04207713ece899c3740823d33690441ad3a7f0ded1101aca744e2b0f37ac7ff2',
      'amd64':
          'c1e67ef7b17a6300e136118bd1dc04725009cb376c1aad10abcf8cd453628d58',
    },
  );

  static const ubuntu24043 = RootfsImage(
    id: 'ubuntu-24.04.3',
    distro: 'ubuntu',
    version: '24.04.3',
    codename: 'noble',
    urls: {
      'armhf':
          'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-armhf.tar.gz',
      'arm64':
          'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-arm64.tar.gz',
      'amd64':
          'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-amd64.tar.gz',
    },
    checksums: {
      'armhf':
          '747909a2f81d816fc6252f076757fcf6bd75a55f848a1c049ee79c0e88c0b9a0',
      'arm64':
          '7b2dced6dd56ad5e4a813fa25c8de307b655fdabc6ea9213175a92c48dabb048',
      'amd64':
          '6bc2cde3930ad088b3bb46fa45279e96d25bc3810f209850ecbe4722711874f9',
    },
  );

  static const ubuntu2204 = RootfsImage(
    id: 'ubuntu-22.04.5',
    distro: 'ubuntu',
    version: '22.04.5',
    codename: 'jammy',
    urls: {
      'armhf':
          'https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.5-base-armhf.tar.gz',
      'arm64':
          'https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.5-base-arm64.tar.gz',
      'amd64':
          'https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.5-base-amd64.tar.gz',
    },
    checksums: {
      'armhf':
          'fd77cb0659326b75c08ce06b6b8649d2e13ef9a704a8e9212fec32cb97d42add',
      'arm64':
          '075d4abd2817a5023ab0a82f5cb314c5ec0aa64a9c0b40fd3154ca3bfdae979f',
      'amd64':
          '242cd8898b33ea806ef5f13b1076ed7c76f9f989d18384452f7166692438ff1a',
    },
  );

  static const alpine324 = RootfsImage(
    id: 'alpine-3.24.1',
    distro: 'alpine',
    version: '3.24.1',
    codename: 'v3.24',
    urls: {
      'armhf':
          'https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/armv7/alpine-minirootfs-3.24.1-armv7.tar.gz',
      'arm64':
          'https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/aarch64/alpine-minirootfs-3.24.1-aarch64.tar.gz',
      'amd64':
          'https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-minirootfs-3.24.1-x86_64.tar.gz',
    },
    checksums: {
      'armhf':
          '50942d567e6ee422c16cb46d5c282ed9d8adc9007c2a483faf4148a18c64ce32',
      'arm64':
          'f55a90f69052c5bd6f92cb09a8f47065970830b194c917a006fb94028e721259',
      'amd64':
          '41f73e3cf5fa919b8aa5ca6b30dc48f0da2720776d7423e2a7748211456fe081',
    },
  );

  static const alpine323 = RootfsImage(
    id: 'alpine-3.23.5',
    distro: 'alpine',
    version: '3.23.5',
    codename: 'v3.23',
    urls: {
      'armhf':
          'https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/armv7/alpine-minirootfs-3.23.5-armv7.tar.gz',
      'arm64':
          'https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/aarch64/alpine-minirootfs-3.23.5-aarch64.tar.gz',
      'amd64':
          'https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.5-x86_64.tar.gz',
    },
    checksums: {
      'armhf':
          '8ab8b50b3695ef5d97291fa232a5228e5f625d2a96186ac26ead032e60d3e82c',
      'arm64':
          'd9a77cb31f715c56afa4f0a5aa42c04cfde813b70ad74a64725902b09c29a6cc',
      'amd64':
          'fae0d78ad39563573ddececfdd55ae1040ed428442e95ea5401cf66d9079b327',
    },
  );

  static const alpine322 = RootfsImage(
    id: 'alpine-3.22.5',
    distro: 'alpine',
    version: '3.22.5',
    codename: 'v3.22',
    urls: {
      'armhf':
          'https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/armv7/alpine-minirootfs-3.22.5-armv7.tar.gz',
      'arm64':
          'https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/aarch64/alpine-minirootfs-3.22.5-aarch64.tar.gz',
      'amd64':
          'https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.5-x86_64.tar.gz',
    },
    checksums: {
      'armhf':
          '28dab3ac4dd9720d219884ce570b5e3dd5eb91670c2f6345462721e3d2d3b088',
      'arm64':
          '3fbc6285032ed46821b511292633d7b2a6306a2e254f590e92bdafff56cf2f70',
      'amd64':
          '4b4daa9fe2fc696c4919c4412a4c3d3e770d8fb70292a004a2c72f5096175282',
    },
  );

  static const debian13 = RootfsImage(
    id: 'debian-13',
    distro: 'debian',
    version: '13',
    codename: 'trixie',
    urls: {
      'armhf':
          'https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/arm32v7/213/artifact/trixie/rootfs.tar.xz',
      'arm64':
          'https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/arm64v8/202/artifact/trixie/rootfs.tar.xz',
      'amd64':
          'https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/237/artifact/trixie/rootfs.tar.xz',
    },
    checksums: {
      'armhf':
          'f0bc7e42087864237f085a78c32f6c6c885993977240b731802aa13adfffcf7f',
      'arm64':
          '4e3bf516609f99ac2db7d48aa8c19ca7a212e104eb574c12ae087e47e45a301d',
      'amd64':
          '5ac675921069d557c992b25bc90a91f43ba71500dbbe7bb8a2f167e6ea7271af',
    },
  );

  static const debian12 = RootfsImage(
    id: 'debian-12',
    distro: 'debian',
    version: '12',
    codename: 'bookworm',
    urls: {
      'armhf':
          'https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/arm32v7/213/artifact/bookworm/rootfs.tar.xz',
      'arm64':
          'https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/arm64v8/202/artifact/bookworm/rootfs.tar.xz',
      'amd64':
          'https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/237/artifact/bookworm/rootfs.tar.xz',
    },
    checksums: {
      'armhf':
          'fa6e705957a1122ac0575bfe349d620f39fdb335ee8aaa82bd31a670d6a385e8',
      'arm64':
          'b886c8a6d33002ab9c674bc88c1f03076b396a61a90ca81179f3587cba63b5f2',
      'amd64':
          'c3c84203cf8f28a82bf10a783f12364355cff9fbc6c8a95cb9a084c5d1afede8',
    },
  );
}
