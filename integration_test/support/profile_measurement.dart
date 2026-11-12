import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Profile-only observations. No timing assertions: the acceptance report owns
/// interpretation, including run-to-run noise and unavailable measurements.
class GenUiProfileMeasurement {
  final results = <String, Object?>{};
  final _renderedInputs = <int, int>{};
  int _inputCount = 0;
  int? _pendingInput;
  bool _inputFrameQueued = false;
  double get refreshRate =>
      ui.PlatformDispatcher.instance.views.first.display.refreshRate;

  /// Only accepted changed inputs are recorded. Coalesced edits count as one
  /// presented state, identified by the actual engine frameNumber after build.
  void acceptedInput(int beganWallUs) {
    _inputCount++;
    _pendingInput = beganWallUs;
    if (_inputFrameQueued) return;
    _inputFrameQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingInput case final input?) {
        _renderedInputs[ui.PlatformDispatcher.instance.frameData.frameNumber] =
            input;
      }
      _pendingInput = null;
      _inputFrameQueued = false;
    });
  }

  Future<void> measure(
    String name,
    Future<void> Function() action, {
    bool latency = false,
  }) async {
    // Drain timings from preceding setup/warmup before starting this interval.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    // A separate bounded record also lets diagnostic CPU traces identify the
    // interval without including logging in the measured action.
    // ignore: avoid_print
    print('GENUI_PROFILE_BEGIN $name');
    final frames = <ui.FrameTiming>[];
    void collect(List<ui.FrameTiming> batch) => frames.addAll(batch);
    _renderedInputs.clear();
    _inputCount = 0;
    SchedulerBinding.instance.addTimingsCallback(collect);
    final start = DateTime.now().microsecondsSinceEpoch;
    var end = start;
    try {
      await action();
      end = DateTime.now().microsecondsSinceEpoch;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(collect);
    }
    int buildWall(ui.FrameTiming f) =>
        f.timestampInMicroseconds(ui.FramePhase.rasterFinishWallTime) -
        (f.timestampInMicroseconds(ui.FramePhase.rasterFinish) -
            f.timestampInMicroseconds(ui.FramePhase.buildStart));
    final measured = frames
        .where((f) => buildWall(f) >= start && buildWall(f) <= end)
        .toList();
    final budget = 1000000 / (refreshRate > 0 ? refreshRate : 60);
    final build = measured.map((f) => f.buildDuration.inMicroseconds).toList();
    final raster = measured
        .map((f) => f.rasterDuration.inMicroseconds)
        .toList();
    final slow = measured
        .where(
          (f) =>
              f.buildDuration.inMicroseconds > budget ||
              f.rasterDuration.inMicroseconds > budget,
        )
        .length;
    final response = <int>[];
    final timingsByNumber = {
      for (final frame in frames) frame.frameNumber: frame,
    };
    if (latency) {
      for (final entry in _renderedInputs.entries) {
        final next = timingsByNumber[entry.key];
        if (next != null) {
          response.add(
            next.timestampInMicroseconds(ui.FramePhase.rasterFinishWallTime) -
                entry.value,
          );
        }
      }
    }
    final result = <String, Object?>{
      'frames': measured.length,
      'elapsedMs': (end - start) / 1000,
      'buildUs': stats(build),
      'rasterUs': stats(raster),
      'stageBudgetUs': budget,
      'slowFrames': slow,
      'slowPercent': measured.isEmpty ? null : slow * 100 / measured.length,
      'rssBytes': ProcessInfo.currentRss,
      if (latency) ...{
        'acceptedInputSamples': _inputCount,
        'drawnInputStates': _renderedInputs.length,
        'matchedInputFrames': response.length,
        'coalescedOrUnpresentedInputs': _inputCount - _renderedInputs.length,
        'inputToRasterFinishUs': stats(response),
        'latencyBoundary':
            'Changed input to raster completion of its frameNumber; excludes hardware input and display scanout',
      },
    };
    record(name, result);
  }

  void record(String name, Map<String, Object?> result) {
    results[name] = result;
    // ignore: avoid_print
    print('GENUI_PROFILE $name ${jsonEncode(result)}');
  }

  static Map<String, num?> stats(List<int> source) {
    if (source.isEmpty) {
      return {'mean': null, 'p50': null, 'p95': null, 'max': null};
    }
    final values = [...source]..sort();
    return {
      'mean': values.reduce((a, b) => a + b) / values.length,
      'p50': values[(values.length * .50).ceil() - 1],
      'p95': values[(values.length * .95).ceil() - 1],
      'max': values.last,
    };
  }

  Map<String, Object?> report(String fixture) => {
    'fixture': fixture,
    'os': Platform.operatingSystemVersion,
    'platform': Platform.operatingSystem,
    'refreshHz': refreshRate,
    'rssBytes': ProcessInfo.currentRss,
    'peakRssBytes': ProcessInfo.maxRss,
    'measurements': results.keys.toList(),
    'binding': WidgetsBinding.instance.runtimeType.toString(),
    'semanticsEnabled': WidgetsBinding.instance.semanticsEnabled,
    'stages': 'build and raster tested separately; durations are not added',
  };
}
