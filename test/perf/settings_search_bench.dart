import 'package:Kelivo/features/settings/search/settings_search_index.dart';
import 'package:Kelivo/l10n/app_localizations_zh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// Run explicitly; benchmarks are excluded from the default test suite.
void main() {
  test('settings search index and keystroke timings', () {
    final build = Stopwatch()..start();
    final index = SettingsSearchIndex(
      AppLocalizationsZh(),
      platform: TargetPlatform.macOS,
    );
    build.stop();
    const queries = [
      '字',
      '字体',
      '语言',
      'font size',
      'tool cards',
      '聊天',
      '不存在的设置',
      'api key',
    ];
    for (var i = 0; i < 100; i++) {
      index.search(queries[i % queries.length]);
    }
    final samples = <int>[];
    final timer = Stopwatch();
    for (var i = 0; i < 2000; i++) {
      timer.reset();
      timer.start();
      index.search(queries[i % queries.length]);
      timer.stop();
      samples.add(timer.elapsedMicroseconds);
    }
    samples.sort();
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    debugPrint(
      'Settings search: ${index.entries.length} entries; '
      'build ${build.elapsedMicroseconds} us; '
      'mean ${mean.toStringAsFixed(1)} us; '
      'p95 ${samples[(samples.length * 0.95).floor()]} us; '
      'max ${samples.last} us (debug test runtime).',
    );
  });
}
