import 'dart:convert';
import 'dart:io';

import 'src/chat_database_v2_benchmark_fixture.dart';

Future<void> main(List<String> arguments) async {
  final outputArgument = arguments
      .where((value) => value.startsWith('--output='))
      .firstOrNull;
  final output = Directory(
    outputArgument?.substring('--output='.length) ??
        '${Directory.systemTemp.path}/kelivo_chat_v2_benchmark',
  );
  final smoke = arguments.contains('--smoke');
  final datasetArgument = arguments
      .where((value) => value.startsWith('--datasets='))
      .firstOrNull;
  final requested = datasetArgument == null
      ? ChatBenchmarkDataset.values
      : datasetArgument
            .substring('--datasets='.length)
            .split(',')
            .map(
              (name) => ChatBenchmarkDataset.values.singleWhere(
                (value) => value.id == name.trim().toUpperCase(),
              ),
            )
            .toList(growable: false);
  final rssBefore = ProcessInfo.currentRss;
  final results = <Map<String, Object?>>[];
  for (final dataset in requested) {
    final fixture = await ChatDatabaseV2BenchmarkFixture.generate(
      dataset: dataset,
      outputDirectory: output,
      smoke: smoke,
    );
    results.add({
      'dataset': dataset.id,
      'path': fixture.path,
      'conversations': fixture.conversations,
      'logicalMessages': fixture.logicalMessages,
      'physicalMessages': fixture.physicalMessages,
      'bytes': fixture.bytes,
      'walPeakBytes': fixture.walPeakBytes,
      'generationMicros': fixture.generationMicros,
      'checkpointMicros': fixture.checkpointMicros,
      'digest': fixture.digest,
      'metrics': ChatDatabaseV2BenchmarkMetrics.measure(fixture),
    });
  }
  final report = {
    'format': 'kelivo-chat-database-v2-benchmark-v1',
    'seed': ChatDatabaseV2BenchmarkFixture.seed,
    'smoke': smoke,
    'dart': Platform.version,
    'os': Platform.operatingSystemVersion,
    'logicalProcessors': Platform.numberOfProcessors,
    'rssBeforeBytes': rssBefore,
    'rssAfterBytes': ProcessInfo.currentRss,
    'datasets': results,
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
