import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

class CountingWorkspaceRuntimeProvider extends WorkspaceRuntimeProvider {
  int refreshCalls = 0;

  @override
  Future<RuntimeStatus> refresh() async {
    refreshCalls += 1;
    return super.refresh();
  }
}

class FakeEnvironmentManager implements EnvironmentManager {
  FakeEnvironmentManager(
    this.env, {
    this.mirrorCategories = const {MirrorCategory.apt},
  });

  @override
  final EnvironmentProvider env;

  @override
  Set<MirrorCategory> mirrorCategories;

  int installCalls = 0;
  int cancelCalls = 0;
  int repairCalls = 0;
  int resetCalls = 0;
  int checkForUpdateCalls = 0;

  EnvironmentState? installResult;
  String? updateVersion;

  @override
  Future<void> install({void Function(EnvironmentState)? onProgress}) async {
    installCalls += 1;
    final result = installResult;
    if (result != null) {
      onProgress?.call(result);
    }
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
  }

  @override
  Future<void> repair() async {
    repairCalls += 1;
  }

  @override
  Future<void> reset() async {
    resetCalls += 1;
  }

  @override
  Future<bool> checkForUpdate() async {
    checkForUpdateCalls += 1;
    return updateVersion != null;
  }

  @override
  Future<void> ensureInstalled() async {
    if (env.state.phase == EnvironmentPhase.ready) return;
    await install();
  }
}

class FakeMirrorService extends MirrorService {
  FakeMirrorService(EnvironmentProvider env)
    : super(
        env: env,
        speedTest: MirrorSpeedTest(
          client: MockClient((_) async => http.Response('', 200)),
        ),
        runInGuest: (_) async => 0,
      );

  List<MirrorProbe> probes = const [];
  final List<(MirrorCategory, Uri)> applied = <(MirrorCategory, Uri)>[];
  final List<MirrorCategory> restored = <MirrorCategory>[];
  int autoDetectCalls = 0;
  Object? autoDetectError;

  @override
  Future<List<MirrorProbe>> detect(
    MirrorCategory category, {
    MirrorCancelToken? cancelToken,
  }) async {
    return List<MirrorProbe>.from(probes);
  }

  @override
  Stream<MirrorProbeResult> probeCategory(
    MirrorCategory category, {
    Duration? timeout,
    MirrorCancelToken? cancelToken,
  }) async* {
    for (final probe in probes) {
      yield MirrorProbeResult(
        category: category,
        entry: MirrorEntry(
          id: probe.uri.host,
          name: probe.uri.host,
          region: MirrorRegion.global,
          baseUrl: '${probe.uri}/',
        ),
        latency: probe.latency,
        error: probe.error,
        timedOut: '${probe.error}' == 'timeout',
      );
    }
  }

  @override
  Future<void> apply(
    MirrorCategory category,
    Uri base, {
    bool manual = true,
    MirrorCancelToken? cancelToken,
  }) async {
    applied.add((category, base));
  }

  @override
  Future<void> applyEntry(
    MirrorCategory category,
    MirrorEntry entry, {
    bool manual = true,
    MirrorCancelToken? cancelToken,
  }) async {
    applied.add((category, entry.baseUri));
    await env.setMirror(
      category,
      MirrorSelection(
        selectedBaseUrl: entry.baseUrl,
        useMirror: !entry.official,
        mirrorId: entry.id,
        displayName: entry.name,
        manual: manual,
      ),
    );
  }

  @override
  Future<void> restoreOfficial(
    MirrorCategory category, {
    bool manual = false,
    MirrorCancelToken? cancelToken,
  }) async {
    restored.add(category);
    final official = MirrorService.officialEntry(category);
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
  }

  @override
  Future<void> autoDetectAndApplyAll({
    required Set<MirrorCategory> categories,
    void Function(MirrorDetectProgress progress)? onProgress,
    bool skipManualPicks = true,
    MirrorCancelToken? cancelToken,
  }) async {
    autoDetectCalls += 1;
    cancelToken?.throwIfCancelled();
    final error = autoDetectError;
    if (error != null) throw error;
  }
}
