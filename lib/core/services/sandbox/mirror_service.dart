import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/guest_scripts.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';

enum MirrorRegion { global, china, europe, asia }

class MirrorEntry {
  const MirrorEntry({
    required this.id,
    required this.name,
    required this.region,
    required this.baseUrl,
    this.official = false,
  });

  final String id;
  final String name;
  final MirrorRegion region;
  final String baseUrl;
  final bool official;

  Uri get baseUri => Uri.parse(_trimSlash(baseUrl));

  Uri probeUri(
    MirrorCategory category, {
    String codename = 'noble',
    String arch = 'arm64',
    String branch = 'v3.21',
  }) {
    final root = Uri.parse(_ensureSlash(baseUrl));
    if (category == MirrorCategory.apt) {
      return root.resolve('dists/$codename/Release');
    }
    if (category == MirrorCategory.apk) {
      final abi = arch == 'amd64' ? 'x86_64' : 'aarch64';
      return root.resolve('$branch/main/$abi/APKINDEX.tar.gz');
    }
    return root.resolve(_probePath(category));
  }

  static String _probePath(MirrorCategory category) {
    switch (category) {
      case MirrorCategory.apk:
        return 'v3.21/main/aarch64/APKINDEX.tar.gz';
      case MirrorCategory.apt:
        return 'dists/noble/Release';
      case MirrorCategory.pip:
        return 'pip/';
      case MirrorCategory.npm:
        return '-/ping';
    }
  }
}

class MirrorProbeResult {
  const MirrorProbeResult({
    required this.category,
    required this.entry,
    this.latency,
    this.error,
    this.timedOut = false,
  });

  final MirrorCategory category;
  final MirrorEntry entry;
  final Duration? latency;
  final Object? error;
  final bool timedOut;

  bool get ok => latency != null && error == null && !timedOut;

  int? get latencyMs => latency?.inMilliseconds;

  MirrorProbe get asProbe => MirrorProbe(
    uri: entry.baseUri,
    latency: latency,
    error: timedOut ? 'timeout' : error,
  );
}

enum MirrorDetectPhase { probing, applying }

class MirrorDetectProgress {
  const MirrorDetectProgress({
    required this.fraction,
    required this.category,
    required this.phase,
    this.result,
  });

  final double fraction;
  final MirrorCategory category;
  final MirrorDetectPhase phase;
  final MirrorProbeResult? result;
}

final class MirrorCancelledException implements Exception {
  const MirrorCancelledException();

  @override
  String toString() => 'MirrorCancelledException';
}

final class MirrorCancelToken {
  bool _cancelled = false;
  final Completer<void> _completer = Completer<void>();
  final List<void Function()> _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  Future<void> get whenCancelled => _completer.future;

  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const MirrorCancelledException();
  }
}

class MirrorService {
  MirrorService({
    required this.env,
    required this.speedTest,
    required this.runInGuest,
    this.cancelGuest,
    http.Client? client,
    this.probeTimeout = const Duration(seconds: 8),
    this.guestTimeout = guestScriptTimeout,
  }) : _client = client ?? http.Client();

  static const String alpineBranch = 'v3.21';
  static const Duration guestScriptTimeout = Duration(seconds: 30);

  final EnvironmentProvider env;
  final MirrorSpeedTest speedTest;
  final Future<int> Function(String shellScript) runInGuest;
  final Future<void> Function()? cancelGuest;
  final http.Client _client;
  final Duration probeTimeout;
  final Duration guestTimeout;
  MirrorCancelToken? _activeCancel;

  static List<MirrorEntry> entriesFor(
    MirrorCategory category, {
    String arch = 'arm64',
    String distro = 'ubuntu',
  }) {
    switch (category) {
      case MirrorCategory.apk:
        return _apk;
      case MirrorCategory.apt:
        if (distro == 'debian') {
          return [
            for (final entry in _apt)
              MirrorEntry(
                id: entry.id,
                name: entry.name,
                region: entry.region,
                official: entry.official,
                baseUrl: entry.official
                    ? 'https://deb.debian.org/debian/'
                    : entry.baseUrl.replaceFirst('/ubuntu-ports/', '/debian/'),
              ),
          ];
        }
        if (arch != 'amd64') return _apt;
        return [
          for (final entry in _apt)
            MirrorEntry(
              id: entry.id,
              name: entry.name,
              region: entry.region,
              official: entry.official,
              baseUrl: entry.baseUrl
                  .replaceFirst('ports.ubuntu.com', 'archive.ubuntu.com')
                  .replaceFirst('/ubuntu-ports/', '/ubuntu/'),
            ),
        ];
      case MirrorCategory.pip:
        return _pip;
      case MirrorCategory.npm:
        return _npm;
    }
  }

  static MirrorEntry officialEntry(
    MirrorCategory category, {
    String arch = 'arm64',
    String distro = 'ubuntu',
  }) {
    return entriesFor(
      category,
      arch: arch,
      distro: distro,
    ).firstWhere((entry) => entry.official);
  }

  static MirrorEntry? findEntry(
    MirrorCategory category, {
    String? id,
    String? url,
    String arch = 'arm64',
    String distro = 'ubuntu',
  }) {
    final entries = entriesFor(category, arch: arch, distro: distro);
    if (id != null && id.isNotEmpty) {
      for (final entry in entries) {
        if (entry.id == id) return entry;
      }
    }
    if (url != null && url.isNotEmpty) {
      final needle = _trimSlash(url);
      for (final entry in entries) {
        if (_trimSlash(entry.baseUrl) == needle) return entry;
      }
    }
    return null;
  }

  Future<List<MirrorProbe>> detect(
    MirrorCategory category, {
    MirrorCancelToken? cancelToken,
  }) async {
    final results = <MirrorProbe>[];
    await for (final result in probeCategory(
      category,
      cancelToken: cancelToken,
    )) {
      results.add(result.asProbe);
    }
    return results;
  }

  Stream<MirrorProbeResult> probeCategory(
    MirrorCategory category, {
    Duration? timeout,
    MirrorCancelToken? cancelToken,
  }) {
    return _probeEntries(
      category,
      entriesFor(category, arch: _arch, distro: _distro),
      timeout,
      cancelToken,
    );
  }

  Stream<MirrorProbeResult> probeCategories(
    Iterable<MirrorCategory> categories, {
    Duration? timeout,
    MirrorCancelToken? cancelToken,
  }) {
    final controller = StreamController<MirrorProbeResult>();
    final list = categories.toList();
    var remaining = list.length;
    if (remaining == 0) {
      return const Stream<MirrorProbeResult>.empty();
    }
    _bindCancel(controller, cancelToken);
    for (final category in list) {
      probeCategory(
        category,
        timeout: timeout,
        cancelToken: cancelToken,
      ).listen(
        (result) {
          if (!controller.isClosed) controller.add(result);
        },
        onError: (Object error, StackTrace stack) {
          if (!controller.isClosed) controller.addError(error, stack);
        },
        onDone: () {
          remaining--;
          if (remaining <= 0 && !controller.isClosed) {
            unawaited(controller.close());
          }
        },
      );
    }
    return controller.stream;
  }

  Future<void> apply(
    MirrorCategory category,
    Uri base, {
    bool manual = true,
    MirrorCancelToken? cancelToken,
  }) {
    final entry =
        findEntry(
          category,
          url: base.toString(),
          arch: _arch,
          distro: _distro,
        ) ??
        MirrorEntry(
          id: base.host,
          name: base.host,
          region: MirrorRegion.global,
          baseUrl: _ensureSlash(base.toString()),
        );
    return applyEntry(
      category,
      entry,
      manual: manual,
      cancelToken: cancelToken,
    );
  }

  Future<void> applyEntry(
    MirrorCategory category,
    MirrorEntry entry, {
    bool manual = true,
    MirrorCancelToken? cancelToken,
  }) {
    return _withCancel(cancelToken, () async {
      if (entry.official) {
        await restoreOfficial(category, manual: manual);
        return;
      }
      final code = await _runGuest(_applyScript(category, entry.baseUri));
      if (code != 0) {
        throw StateError('guest mirror apply exited $code');
      }
      await env.setMirror(
        category,
        MirrorSelection(
          selectedBaseUrl: entry.baseUrl,
          useMirror: true,
          mirrorId: entry.id,
          displayName: entry.name,
          manual: manual,
        ),
      );
    });
  }

  Future<void> restoreOfficial(
    MirrorCategory category, {
    bool manual = false,
    MirrorCancelToken? cancelToken,
  }) {
    return _withCancel(cancelToken, () async {
      final official = officialEntry(category, arch: _arch, distro: _distro);
      final code = await _runGuest(_applyScript(category, official.baseUri));
      if (code != 0) throw StateError('guest mirror restore exited $code');
      await env.setMirror(
        category,
        MirrorSelection(
          selectedBaseUrl: official.baseUrl,
          useMirror: false,
          mirrorId: official.id,
          displayName: official.name,
          manual: manual,
        ),
      );
    });
  }

  Future<void> autoDetectAndApplyAll({
    required Set<MirrorCategory> categories,
    void Function(MirrorDetectProgress progress)? onProgress,
    bool skipManualPicks = true,
    MirrorCancelToken? cancelToken,
  }) {
    return _withCancel(cancelToken, () async {
      final ordered = categories.toList();
      final total = ordered.fold<int>(
        0,
        (sum, category) =>
            sum + entriesFor(category, arch: _arch, distro: _distro).length,
      );
      final collected = <MirrorCategory, List<MirrorProbeResult>>{};
      var done = 0;
      await for (final result in probeCategories(
        ordered,
        cancelToken: cancelToken ?? _activeCancel,
      )) {
        _throwIfCancelled();
        collected
            .putIfAbsent(result.category, () => <MirrorProbeResult>[])
            .add(result);
        done += 1;
        onProgress?.call(
          MirrorDetectProgress(
            fraction: total < 1 ? 0.8 : 0.8 * (done / total),
            category: result.category,
            phase: MirrorDetectPhase.probing,
            result: result,
          ),
        );
      }
      _throwIfCancelled();
      final applyTotal = ordered.isEmpty ? 1 : ordered.length;
      var applied = 0;
      for (final category in ordered) {
        _throwIfCancelled();
        onProgress?.call(
          MirrorDetectProgress(
            fraction: 0.8 + 0.2 * (applied / applyTotal),
            category: category,
            phase: MirrorDetectPhase.applying,
          ),
        );
        final existing = env.mirrors[category];
        if (skipManualPicks && (existing?.hasManualPick ?? false)) {
          applied += 1;
          onProgress?.call(
            MirrorDetectProgress(
              fraction: 0.8 + 0.2 * (applied / applyTotal),
              category: category,
              phase: MirrorDetectPhase.applying,
            ),
          );
          continue;
        }
        final hits =
            (collected[category] ?? const <MirrorProbeResult>[])
                .where((item) => item.ok)
                .toList()
              ..sort((a, b) => a.latency!.compareTo(b.latency!));
        if (hits.isEmpty || hits.first.entry.official) {
          await restoreOfficial(category);
        } else {
          await applyEntry(category, hits.first.entry, manual: false);
        }
        applied += 1;
        onProgress?.call(
          MirrorDetectProgress(
            fraction: 0.8 + 0.2 * (applied / applyTotal),
            category: category,
            phase: MirrorDetectPhase.applying,
          ),
        );
      }
    });
  }

  Stream<MirrorProbeResult> _probeEntries(
    MirrorCategory category,
    List<MirrorEntry> entries,
    Duration? timeout,
    MirrorCancelToken? cancelToken,
  ) {
    if (entries.isEmpty) {
      return const Stream<MirrorProbeResult>.empty();
    }
    final token = cancelToken ?? _activeCancel;
    final controller = StreamController<MirrorProbeResult>();
    _bindCancel(controller, token);
    var remaining = entries.length;
    for (final entry in entries) {
      unawaited(
        _probeOne(category, entry, timeout ?? probeTimeout, token)
            .then((result) {
              if (!controller.isClosed) controller.add(result);
            })
            .catchError((Object error, StackTrace stack) {
              if (error is MirrorCancelledException) {
                if (!controller.isClosed) unawaited(controller.close());
                return;
              }
              if (!controller.isClosed) {
                controller.addError(error, stack);
              }
            })
            .whenComplete(() {
              remaining--;
              if (remaining <= 0 && !controller.isClosed) {
                unawaited(controller.close());
              }
            }),
      );
    }
    return controller.stream;
  }

  Future<MirrorProbeResult> _probeOne(
    MirrorCategory category,
    MirrorEntry entry,
    Duration timeout,
    MirrorCancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    final uri = entry.probeUri(
      category,
      codename: _codename,
      arch: _arch,
      branch: _alpineBranch,
    );
    final sw = Stopwatch()..start();
    try {
      try {
        if (await _tryRequest('HEAD', uri, timeout, cancelToken: cancelToken)) {
          sw.stop();
          return MirrorProbeResult(
            category: category,
            entry: entry,
            latency: sw.elapsed,
          );
        }
      } on TimeoutException {
        rethrow;
      } on MirrorCancelledException {
        rethrow;
      } catch (_) {
        // HEAD unsupported or rejected — fall back to a ranged GET.
      }
      cancelToken?.throwIfCancelled();
      if (await _tryRequest(
        'GET',
        uri,
        timeout,
        range: true,
        cancelToken: cancelToken,
      )) {
        sw.stop();
        return MirrorProbeResult(
          category: category,
          entry: entry,
          latency: sw.elapsed,
        );
      }
      sw.stop();
      return MirrorProbeResult(
        category: category,
        entry: entry,
        error: 'HTTP error',
      );
    } on TimeoutException {
      sw.stop();
      return MirrorProbeResult(
        category: category,
        entry: entry,
        timedOut: true,
      );
    } on MirrorCancelledException {
      rethrow;
    } catch (error) {
      sw.stop();
      return MirrorProbeResult(category: category, entry: entry, error: error);
    }
  }

  Future<bool> _tryRequest(
    String method,
    Uri uri,
    Duration timeout, {
    bool range = false,
    MirrorCancelToken? cancelToken,
  }) async {
    final request = http.Request(method, uri);
    if (range) {
      request.headers['range'] = 'bytes=0-0';
      request.headers['Range'] = 'bytes=0-0';
    }
    final response = await _guarded(
      _client.send(request).timeout(timeout),
      cancelToken,
    );
    if (response.statusCode >= 400) return false;
    if (method == 'GET') {
      await _guarded(
        response.stream.drain<void>().timeout(timeout),
        cancelToken,
      );
    } else {
      unawaited(response.stream.drain<void>());
    }
    return true;
  }

  Future<T> _withCancel<T>(
    MirrorCancelToken? token,
    Future<T> Function() body,
  ) async {
    if (token == null) {
      _throwIfCancelled();
      return body();
    }
    final previous = _activeCancel;
    _activeCancel = token;
    try {
      token.throwIfCancelled();
      return await body();
    } finally {
      _activeCancel = previous;
    }
  }

  void _throwIfCancelled() {
    _activeCancel?.throwIfCancelled();
  }

  void _bindCancel(
    StreamController<MirrorProbeResult> controller,
    MirrorCancelToken? token,
  ) {
    if (token == null) return;
    token.addListener(() {
      if (!controller.isClosed) {
        unawaited(controller.close());
      }
    });
  }

  Future<T> _guarded<T>(Future<T> future, MirrorCancelToken? token) {
    final active = token ?? _activeCancel;
    if (active == null) return future;
    active.throwIfCancelled();
    return Future.any<T>([
      future,
      active.whenCancelled.then((_) {
        throw const MirrorCancelledException();
      }),
    ]);
  }

  Future<int> _runGuest(String script) async {
    _throwIfCancelled();
    try {
      return await _guarded(runInGuest(script).timeout(guestTimeout), null);
    } on TimeoutException {
      await cancelGuest?.call();
      throw StateError(
        'guest mirror script timed out after ${guestTimeout.inSeconds}s',
      );
    } on MirrorCancelledException {
      await cancelGuest?.call();
      rethrow;
    }
  }

  String _applyScript(MirrorCategory category, Uri base) {
    final url = base.toString();
    switch (category) {
      case MirrorCategory.apt:
        return GuestScripts.applyAptMirror(
          url,
          _arch,
          distro: _distro,
          codename: _codename,
        );
      case MirrorCategory.apk:
        return GuestScripts.applyApkMirror(url, _alpineBranch);
      case MirrorCategory.pip:
        return GuestScripts.applyPipMirror(url);
      case MirrorCategory.npm:
        return GuestScripts.applyNpmMirror(url);
    }
  }

  String get _arch => env.state.arch ?? 'arm64';
  String get _distro => env.state.distro ?? 'ubuntu';
  String get _codename => env.state.codename?.isNotEmpty == true
      ? env.state.codename!
      : _distro == 'debian'
      ? (env.state.version?.startsWith('13') == true ? 'trixie' : 'bookworm')
      : env.state.version?.startsWith('22.04') == true
      ? 'jammy'
      : 'noble';
  String get _alpineBranch {
    final version = env.state.version?.replaceFirst('alpine-', '').split('.');
    return version != null && version.length >= 2
        ? 'v${version[0]}.${version[1]}'
        : alpineBranch;
  }

  static const List<MirrorEntry> _apk = [
    MirrorEntry(
      id: 'alpine.official',
      name: 'Official CDN',
      region: MirrorRegion.global,
      baseUrl: 'https://dl-cdn.alpinelinux.org/alpine/',
      official: true,
    ),
    MirrorEntry(
      id: 'alpine.tuna',
      name: 'Tsinghua TUNA',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.tuna.tsinghua.edu.cn/alpine/',
    ),
    MirrorEntry(
      id: 'alpine.aliyun',
      name: 'Alibaba',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.aliyun.com/alpine/',
    ),
    MirrorEntry(
      id: 'alpine.ustc',
      name: 'USTC',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.ustc.edu.cn/alpine/',
    ),
    MirrorEntry(
      id: 'alpine.huawei',
      name: 'Huawei',
      region: MirrorRegion.china,
      baseUrl: 'https://repo.huaweicloud.com/alpine/',
    ),
    MirrorEntry(
      id: 'alpine.tencent',
      name: 'Tencent',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.cloud.tencent.com/alpine/',
    ),
    MirrorEntry(
      id: 'alpine.leaseweb',
      name: 'LEASEWEB UK',
      region: MirrorRegion.europe,
      baseUrl: 'https://mirror.leaseweb.com/alpine/',
    ),
    MirrorEntry(
      id: 'alpine.rwth',
      name: 'RWTH Germany',
      region: MirrorRegion.europe,
      baseUrl: 'https://ftp.halifax.rwth-aachen.de/alpine/',
    ),
    MirrorEntry(
      id: 'alpine.jaist',
      name: 'JAIST Japan',
      region: MirrorRegion.asia,
      baseUrl: 'https://ftp.jaist.ac.jp/pub/Linux/alpine/',
    ),
    MirrorEntry(
      id: 'alpine.kakao',
      name: 'Kakao Korea',
      region: MirrorRegion.asia,
      baseUrl: 'https://mirror.kakao.com/alpine/',
    ),
  ];

  static const List<MirrorEntry> _apt = [
    MirrorEntry(
      id: 'apt.official',
      name: 'Official',
      region: MirrorRegion.global,
      baseUrl: 'http://ports.ubuntu.com/ubuntu-ports/',
      official: true,
    ),
    MirrorEntry(
      id: 'apt.tuna',
      name: 'Tsinghua TUNA',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/',
    ),
    MirrorEntry(
      id: 'apt.aliyun',
      name: 'Alibaba',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.aliyun.com/ubuntu-ports/',
    ),
    MirrorEntry(
      id: 'apt.ustc',
      name: 'USTC',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.ustc.edu.cn/ubuntu-ports/',
    ),
    MirrorEntry(
      id: 'apt.huawei',
      name: 'Huawei',
      region: MirrorRegion.china,
      baseUrl: 'https://repo.huaweicloud.com/ubuntu-ports/',
    ),
    MirrorEntry(
      id: 'apt.tencent',
      name: 'Tencent',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.cloud.tencent.com/ubuntu-ports/',
    ),
    MirrorEntry(
      id: 'apt.netease',
      name: 'NetEase',
      region: MirrorRegion.china,
      baseUrl: 'http://mirrors.163.com/ubuntu-ports/',
    ),
  ];

  static const List<MirrorEntry> _pip = [
    MirrorEntry(
      id: 'pip.official',
      name: 'Official PyPI',
      region: MirrorRegion.global,
      baseUrl: 'https://pypi.org/simple/',
      official: true,
    ),
    MirrorEntry(
      id: 'pip.tuna',
      name: 'Tsinghua TUNA',
      region: MirrorRegion.china,
      baseUrl: 'https://pypi.tuna.tsinghua.edu.cn/simple/',
    ),
    MirrorEntry(
      id: 'pip.aliyun',
      name: 'Alibaba',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.aliyun.com/pypi/simple/',
    ),
    MirrorEntry(
      id: 'pip.ustc',
      name: 'USTC',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.ustc.edu.cn/pypi/web/simple/',
    ),
    MirrorEntry(
      id: 'pip.huawei',
      name: 'Huawei',
      region: MirrorRegion.china,
      baseUrl: 'https://repo.huaweicloud.com/repository/pypi/simple/',
    ),
    MirrorEntry(
      id: 'pip.tencent',
      name: 'Tencent',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.cloud.tencent.com/pypi/simple/',
    ),
  ];

  static const List<MirrorEntry> _npm = [
    MirrorEntry(
      id: 'npm.official',
      name: 'Official npm',
      region: MirrorRegion.global,
      baseUrl: 'https://registry.npmjs.org/',
      official: true,
    ),
    MirrorEntry(
      id: 'npm.npmmirror',
      name: 'npmmirror',
      region: MirrorRegion.china,
      baseUrl: 'https://registry.npmmirror.com/',
    ),
    MirrorEntry(
      id: 'npm.huawei',
      name: 'Huawei',
      region: MirrorRegion.china,
      baseUrl: 'https://repo.huaweicloud.com/repository/npm/',
    ),
    MirrorEntry(
      id: 'npm.tencent',
      name: 'Tencent',
      region: MirrorRegion.china,
      baseUrl: 'https://mirrors.cloud.tencent.com/npm/',
    ),
  ];
}

String _trimSlash(String value) {
  if (value.endsWith('/')) {
    return value.substring(0, value.length - 1);
  }
  return value;
}

String _ensureSlash(String value) {
  return value.endsWith('/') ? value : '$value/';
}
