// Dedicated emulator entrypoint. Never used by the production app.
// No model credentials are used.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/models/mobile_background_settings.dart';
import 'package:Kelivo/core/services/mobile_background.dart';
import 'package:Kelivo/core/services/notification_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final folder = await getApplicationSupportDirectory();
  final database = AppDatabase(
    NativeDatabase.createInBackground(
      File('${folder.path}/background-smoke.sqlite'),
    ),
  );
  await database.customStatement(
    'CREATE TABLE IF NOT EXISTS background_smoke (run TEXT, step INTEGER, hash TEXT)',
  );
  await NotificationService.ensureInitialized();
  final coordinator = MobileBackgroundCoordinator.instance;
  await coordinator.configure(
    const MobileBackgroundSettings(
      androidEnabled: true,
      iosEnabled: true,
      notificationsEnabled: true,
      liveActivitiesEnabled: true,
    ),
    await AppLocalizations.delegate.load(const Locale('en')),
  );
  runApp(
    MaterialApp(
      home: _SmokePage(
        folder: folder,
        database: database,
        coordinator: coordinator,
      ),
    ),
  );
}

class _SmokePage extends StatefulWidget {
  const _SmokePage({
    required this.folder,
    required this.database,
    required this.coordinator,
  });
  final Directory folder;
  final AppDatabase database;
  final MobileBackgroundCoordinator coordinator;
  @override
  State<_SmokePage> createState() => _SmokePageState();
}

class _SmokePageState extends State<_SmokePage> {
  String status = 'Ready';
  bool running = false;
  final nonce = DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    if (const bool.fromEnvironment('SMOKE_AUTOSTART')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(start()));
    }
  }

  Future<void> start() async {
    if (running) return;
    running = true;
    final client = HttpClient();
    var cancelled = false;
    var count = 0;
    String hash = '';
    final source = File('${widget.folder.path}/background-smoke-input.txt');
    await source.writeAsString('abc');
    Future<void> checkpoint(String phase) async {
      await File('${widget.folder.path}/background-smoke.json').writeAsString(
        jsonEncode({
          'engine': nonce,
          'pid': pid,
          'steps': count,
          'hash': hash,
          'phase': phase,
          'status': widget.coordinator.status.values,
        }),
        flush: true,
      );
      if (mounted) setState(() => status = '$phase: $count\nEngine: $nonce');
    }

    await widget.coordinator.start(
      id: nonce,
      conversationId: 'background-smoke',
      title: 'Background smoke test',
      cancel: () async {
        cancelled = true;
        client.close(force: true);
      },
    );
    try {
      await checkpoint('connecting');
      final request = await client.getUrl(
        Uri.parse(
          const String.fromEnvironment(
            'SMOKE_URL',
            defaultValue: 'http://10.0.2.2:8769/stream',
          ),
        ),
      );
      final response = await request.close();
      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        count++;
        widget.coordinator.update(
          nonce,
          phase: BackgroundTaskPhase.tool,
          tokens: count,
          toolName: 'sha256File',
        );
        hash =
            await const MethodChannel(
              'app.workspace',
            ).invokeMethod<String>('sha256File', {'path': source.path}) ??
            '';
        if (hash !=
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad') {
          throw StateError('Native workspace tool result was corrupted');
        }
        await widget.database.customStatement(
          'INSERT INTO background_smoke VALUES (?, ?, ?)',
          [nonce, count, hash],
        );
        widget.coordinator.update(
          nonce,
          phase: BackgroundTaskPhase.generating,
          tokens: count,
        );
        await checkpoint('streaming');
      }
      final rows = await widget.database
          .customSelect(
            'SELECT COUNT(*) AS n FROM background_smoke WHERE run = ?',
            variables: [Variable<String>(nonce)],
          )
          .get();
      // Persisted rows are inspected independently with sqlite3 on the host.
      if (rows.single.read<int>('n') != count) {
        throw StateError('Missing database result');
      }
      await widget.coordinator.finish(nonce, BackgroundTaskOutcome.completed);
      await checkpoint('completed');
    } catch (error) {
      await widget.coordinator.finish(
        nonce,
        cancelled
            ? BackgroundTaskOutcome.cancelled
            : BackgroundTaskOutcome.failed,
      );
      await checkpoint(cancelled ? 'cancelled' : 'failed: $error');
    } finally {
      client.close(force: true);
      running = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Background runtime smoke test')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status, textAlign: TextAlign.center),
          TextButton(
            onPressed: running ? null : start,
            child: const Text('Start local stream'),
          ),
        ],
      ),
    ),
  );
}
