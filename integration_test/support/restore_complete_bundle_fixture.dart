import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';

import 'restore_process_control.dart';

const restoreHarnessAssetRoots = ['upload', 'images', 'avatars', 'fonts'];

final class RestoreCompleteBundleFixtureState {
  const RestoreCompleteBundleFixtureState({
    required this.runId,
    required this.preparedReceiptChecksum,
    required this.candidateManifestSha256,
    required this.preferenceKey,
    required this.oldPreferenceValue,
    required this.newPreferenceValue,
    required this.oldConversationId,
    required this.newConversationId,
  });

  final String runId;
  final String preparedReceiptChecksum;
  final String candidateManifestSha256;
  final String preferenceKey;
  final String oldPreferenceValue;
  final String newPreferenceValue;
  final String oldConversationId;
  final String newConversationId;

  Map<String, dynamic> toJson() => {
    'format': restoreHarnessFormat,
    'version': 1,
    'runId': runId,
    'preparedReceiptChecksum': preparedReceiptChecksum,
    'candidateManifestSha256': candidateManifestSha256,
    'preferenceKey': preferenceKey,
    'oldPreferenceValue': oldPreferenceValue,
    'newPreferenceValue': newPreferenceValue,
    'oldConversationId': oldConversationId,
    'newConversationId': newConversationId,
  };

  factory RestoreCompleteBundleFixtureState.fromJson(
    Map<dynamic, dynamic> source,
  ) {
    const expectedKeys = {
      'format',
      'version',
      'runId',
      'preparedReceiptChecksum',
      'candidateManifestSha256',
      'preferenceKey',
      'oldPreferenceValue',
      'newPreferenceValue',
      'oldConversationId',
      'newConversationId',
    };
    if (source.keys.any((key) => key is! String) ||
        source.length != expectedKeys.length ||
        !source.keys.toSet().containsAll(expectedKeys)) {
      throw const FormatException('restore_harness_state_fields');
    }
    final json = source.cast<String, dynamic>();
    if (json['format'] != restoreHarnessFormat || json['version'] != 1) {
      throw const FormatException('restore_harness_state_header');
    }
    for (final key in expectedKeys.difference({'version'})) {
      if (json[key] is! String) {
        throw const FormatException('restore_harness_state_types');
      }
    }
    return RestoreCompleteBundleFixtureState(
      runId: json['runId'] as String,
      preparedReceiptChecksum: json['preparedReceiptChecksum'] as String,
      candidateManifestSha256: json['candidateManifestSha256'] as String,
      preferenceKey: json['preferenceKey'] as String,
      oldPreferenceValue: json['oldPreferenceValue'] as String,
      newPreferenceValue: json['newPreferenceValue'] as String,
      oldConversationId: json['oldConversationId'] as String,
      newConversationId: json['newConversationId'] as String,
    );
  }

  static Future<RestoreCompleteBundleFixtureState> read(
    RestoreProcessHarnessControl control,
  ) async {
    return RestoreCompleteBundleFixtureState.fromJson(
      await readHarnessJson(control.stateFile),
    );
  }
}

Future<RestoreCompleteBundleFixtureState> prepareCompleteBundleFixture(
  RestoreProcessHarnessControl control,
) async {
  final appData = control.appDataDirectory;
  final source = control.sourceDirectory;
  await appData.create(recursive: true);
  await source.create(recursive: true);

  final oldConversationId = 'old-${control.scenarioId}';
  final newConversationId = 'new-${control.scenarioId}';
  final preferenceKey = 'restore_harness_${control.scenarioId}';
  const oldPreferenceValue = 'old';
  const newPreferenceValue = 'new';

  await createHarnessDatabase(
    File(p.join(appData.path, AppDatabase.databaseFileName)),
    conversationId: oldConversationId,
  );
  for (final root in restoreHarnessAssetRoots) {
    final file = File(p.join(appData.path, root, 'old.txt'));
    await file.parent.create(recursive: true);
    await file.writeAsString('old:$root', flush: true);
  }

  final settingsFile = File(p.join(source.path, 'settings.json'));
  await settingsFile.writeAsString(
    jsonEncode({preferenceKey: newPreferenceValue}),
    flush: true,
  );
  final candidateDatabase = File(
    p.join(source.path, 'database', AppDatabase.databaseFileName),
  );
  await candidateDatabase.parent.create(recursive: true);
  await createHarnessDatabase(
    candidateDatabase,
    conversationId: newConversationId,
  );
  final databaseInfo = await ChatDatabaseRepository.prepareSnapshotForRestore(
    candidateDatabase,
  );

  final entries = <String, Map<String, dynamic>>{
    'settings.json': await harnessFileDescriptor(settingsFile),
    'database/${AppDatabase.databaseFileName}': await harnessFileDescriptor(
      candidateDatabase,
    ),
  };
  for (final root in restoreHarnessAssetRoots) {
    final file = File(p.join(source.path, root, 'new.txt'));
    await file.parent.create(recursive: true);
    await file.writeAsString('new:$root', flush: true);
    entries['$root/new.txt'] = await harnessFileDescriptor(file);
  }

  final manifestFile = File(p.join(source.path, 'manifest.json'));
  await manifestFile.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'sqlite',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'restore-process-harness',
      'includeChats': true,
      'includeFiles': true,
      'secretsIncluded': true,
      'database': {
        'entry': 'database/${AppDatabase.databaseFileName}',
        'schemaVersion': databaseInfo.schemaVersion,
        'conversationCount': databaseInfo.conversationCount,
        'messageCount': databaseInfo.messageCount,
      },
      'entries': entries,
    }),
    flush: true,
  );

  final prepared = await RestoreBundlePreparation.prepare(
    appDataDirectory: appData,
    extractedDirectory: source,
    sourceManifestSha256: await harnessFileSha256(manifestFile),
    bundleIncludesChats: true,
    bundleIncludesFiles: true,
    restoreChats: true,
    restoreFiles: true,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
  );
  return RestoreCompleteBundleFixtureState(
    runId: prepared.runId,
    preparedReceiptChecksum: prepared.receipt.checksum,
    candidateManifestSha256: prepared.receipt.candidateManifestSha256,
    preferenceKey: preferenceKey,
    oldPreferenceValue: oldPreferenceValue,
    newPreferenceValue: newPreferenceValue,
    oldConversationId: oldConversationId,
    newConversationId: newConversationId,
  );
}

Future<void> createHarnessDatabase(
  File file, {
  required String conversationId,
}) async {
  final repository = ChatDatabaseRepository.open(file: file);
  try {
    await repository.ensureReady();
    await repository.putMigrationBatch(
      conversations: [Conversation(id: conversationId, title: conversationId)],
      messages: const [],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repository.markMigrationComplete();
    await repository.checkpoint();
  } finally {
    await repository.close();
  }
}

Future<List<String>> harnessConversationIds(File file) async {
  final database = sqlite.sqlite3.open(
    file.path,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    return database
        .select('SELECT id FROM conversation_rows ORDER BY id;')
        .map((row) => row['id'] as String)
        .toList(growable: false);
  } finally {
    database.close();
  }
}

Future<Map<String, dynamic>> harnessFileDescriptor(File file) async {
  return {
    'bytes': await file.length(),
    'sha256': await harnessFileSha256(file),
  };
}

Future<String> harnessFileSha256(File file) async {
  return (await sha256.bind(file.openRead()).first).toString();
}
