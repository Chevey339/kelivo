import 'dart:io';

Future<void> main() async {
  final commands = <List<String>>[
    ['flutter', 'analyze'],
    [
      'flutter',
      'test',
      'test/core/database/chat_database_repository_streaming_checkpoint_test.dart',
      'test/features/home/controllers/latest_wins_checkpoint_writer_test.dart',
      'test/features/home/controllers/active_streaming_message_store_test.dart',
      'test/core/database/chat_database_repository_merge_test.dart',
      'test/core/database/database_installation_gate_test.dart',
      'test/core/database/chat_database_repository_sandbox_path_migration_test.dart',
      'test/tool/chat_database_v2_benchmark_fixture_test.dart',
    ],
  ];
  for (final command in commands) {
    stdout.writeln('\$ ${command.join(' ')}');
    final process = await Process.start(
      command.first,
      command.skip(1).toList(growable: false),
      mode: ProcessStartMode.inheritStdio,
    );
    final exitCode = await process.exitCode;
    if (exitCode != 0) exit(exitCode);
  }
}
