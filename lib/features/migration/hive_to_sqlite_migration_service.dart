import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/database/chat_database_repository.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/conversation.dart';
import '../../core/models/message_part.dart';
import '../../core/services/backup/backup_settings_validator.dart';
import '../../core/services/backup/restore_durability.dart';
import '../../core/services/hive_migration_marker.dart';
import '../../core/services/migration/legacy_message_content_decoder.dart';
import '../../core/services/migration/legacy_record_sanitizer.dart';
import '../../utils/app_directories.dart';
import '../../utils/sandbox_path_resolver.dart';

enum HiveToSqliteMigrationStage {
  intro,
  backupReady,
  backingUp,
  migrating,
  complete,
  failed,
}

enum HiveToSqliteBackupItemState { pending, active, done }

typedef MigrationBackupChunkWriter = Future<void> Function(Uint8List bytes);

class HiveToSqliteBackupItem {
  const HiveToSqliteBackupItem({
    required this.name,
    required this.bytes,
    this.writtenBytes = 0,
    this.state = HiveToSqliteBackupItemState.pending,
  });

  final String name;
  final int bytes;
  final int writtenBytes;
  final HiveToSqliteBackupItemState state;

  HiveToSqliteBackupItem copyWith({
    int? bytes,
    int? writtenBytes,
    HiveToSqliteBackupItemState? state,
  }) {
    return HiveToSqliteBackupItem(
      name: name,
      bytes: bytes ?? this.bytes,
      writtenBytes: writtenBytes ?? this.writtenBytes,
      state: state ?? this.state,
    );
  }
}

class HiveToSqliteMigrationStatus {
  const HiveToSqliteMigrationStatus({
    required this.stage,
    required this.progress,
    required this.title,
    this.detail = '',
    this.backupPath,
    this.error,
    this.log = const <String>[],
    this.conversations = 0,
    this.messages = 0,
    this.converted = 0,
    this.malformed = 0,
    this.missingFiles = 0,
    this.backupItems = const <HiveToSqliteBackupItem>[],
    this.chatsExportDegraded = false,
  });

  final HiveToSqliteMigrationStage stage;
  final double progress;
  final String title;
  final String detail;
  final String? backupPath;
  final String? error;
  final List<String> log;
  final int conversations;
  final int messages;

  /// Legacy attachment markers successfully converted to parts.
  final int converted;

  /// Marker-shaped lines that could not be parsed and were kept as text.
  final int malformed;

  /// Converted local attachments whose files were missing on disk.
  final int missingFiles;
  final List<HiveToSqliteBackupItem> backupItems;
  final bool chatsExportDegraded;

  HiveToSqliteMigrationStatus copyWith({
    HiveToSqliteMigrationStage? stage,
    double? progress,
    String? title,
    String? detail,
    String? backupPath,
    String? error,
    List<String>? log,
    int? conversations,
    int? messages,
    int? converted,
    int? malformed,
    int? missingFiles,
    List<HiveToSqliteBackupItem>? backupItems,
    bool? chatsExportDegraded,
  }) {
    return HiveToSqliteMigrationStatus(
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      backupPath: backupPath ?? this.backupPath,
      error: error ?? this.error,
      log: log ?? this.log,
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      converted: converted ?? this.converted,
      malformed: malformed ?? this.malformed,
      missingFiles: missingFiles ?? this.missingFiles,
      backupItems: backupItems ?? this.backupItems,
      chatsExportDegraded: chatsExportDegraded ?? this.chatsExportDegraded,
    );
  }
}

class HiveToSqliteMigrationDecision {
  const HiveToSqliteMigrationDecision({
    required this.needsMigration,
    required this.appDataDir,
    required this.sqliteFile,
    required this.hiveFiles,
  });

  final bool needsMigration;
  final Directory appDataDir;
  final File sqliteFile;
  final List<File> hiveFiles;
}

class HiveToSqliteMigrationService {
  HiveToSqliteMigrationService(this.decision, {RestoreDurability? durability})
    : _durability = durability ?? RestorePlatformDurability();

  static const skipAttemptThreshold = 2;
  static const _attemptStateFileName =
      'hive_to_sqlite_migration_attempt_v1.json';
  static const _conversationBoxName = 'conversations';
  static const _messagesBoxName = 'messages';
  static const _toolEventsBoxName = 'tool_events_v1';
  static const _messageBatchSize = 128;
  static const _settingsBackupName = 'settings.json';
  static const _chatsBackupName = 'chats.json';
  static const _legacyBusinessKeysNeededForRecovery = <String>{
    'instruction_injections_active_id_v1',
    'instruction_injections_active_ids_v1',
  };
  static const _backupPreparationShare = 0.15;
  static const _backupDirectories =
      <({String directoryName, String zipPrefix})>[
        (directoryName: 'upload', zipPrefix: 'upload'),
        (directoryName: 'images', zipPrefix: 'images'),
        (directoryName: 'avatars', zipPrefix: 'avatars'),
        (directoryName: 'fonts', zipPrefix: 'fonts'),
      ];

  final HiveToSqliteMigrationDecision decision;

  /// Invoked after all batches are written and immediately before [_validate].
  /// Tests use this to corrupt the temporary database and assert rollback.
  @visibleForTesting
  Future<void> Function(ChatDatabaseRepository repo)?
  debugBeforeValidateForTest;

  /// Message ids whose per-message processing should throw, simulating a
  /// corrupt/undecodable legacy record. Tests use this to assert that a single
  /// bad message is isolated instead of failing the whole migration.
  @visibleForTesting
  Set<String> debugFailMessageIdsForTest = <String>{};
  @visibleForTesting
  Set<String> debugFailConversationKeysForTest = <String>{};
  @visibleForTesting
  Set<String> debugFailPrescanMessageIdsForTest = <String>{};
  @visibleForTesting
  int? debugZip64ThresholdForTest;
  final RestoreDurability _durability;
  final _controller = StreamController<HiveToSqliteMigrationStatus>.broadcast();
  final _log = <String>[];
  var _lastBackupItems = const <HiveToSqliteBackupItem>[];
  var _chatsExportDegraded = false;
  var _attemptCount = 0;
  var _converted = 0;
  var _malformed = 0;
  var _missingFiles = 0;
  String? _persistedStageBreadcrumb;

  Stream<HiveToSqliteMigrationStatus> get statusStream => _controller.stream;

  int get attemptCount => _attemptCount;

  bool get canOfferSkip => _attemptCount >= skipAttemptThreshold;

  String? get lastAttemptStage => _persistedStageBreadcrumb;

  Future<int> loadAttemptState() async {
    final state = await _readAttemptState();
    _attemptCount = state.attempts;
    _persistedStageBreadcrumb = state.stage;
    return _attemptCount;
  }

  static Future<HiveToSqliteMigrationDecision> check() async {
    final appDataDir = await AppDirectories.getAppDataDirectory();
    final sqliteFile = File(
      p.join(appDataDir.path, AppDatabase.databaseFileName),
    );
    final hiveFiles = <File>[
      File(p.join(appDataDir.path, 'conversations.hive')),
      File(p.join(appDataDir.path, 'messages.hive')),
      File(p.join(appDataDir.path, 'tool_events_v1.hive')),
    ].where((file) => file.existsSync()).toList(growable: false);

    if (hiveFiles.isEmpty) {
      return HiveToSqliteMigrationDecision(
        needsMigration: false,
        appDataDir: appDataDir,
        sqliteFile: sqliteFile,
        hiveFiles: hiveFiles,
      );
    }
    // Read the receipt off the file rather than through a live connection:
    // this runs before the installation gate upgrades the database, and a live
    // connection refuses any schema that is not already current.
    if (sqliteFile.existsSync() &&
        HiveMigrationMarker.requireMigrationComplete(sqliteFile)) {
      await _deleteSqliteFamilyStatic(File('${sqliteFile.path}.previous'));
      return HiveToSqliteMigrationDecision(
        needsMigration: false,
        appDataDir: appDataDir,
        sqliteFile: sqliteFile,
        hiveFiles: hiveFiles,
      );
    }

    return HiveToSqliteMigrationDecision(
      needsMigration: true,
      appDataDir: appDataDir,
      sqliteFile: sqliteFile,
      hiveFiles: hiveFiles,
    );
  }

  HiveToSqliteMigrationStatus initialStatus() {
    return HiveToSqliteMigrationStatus(
      stage: HiveToSqliteMigrationStage.intro,
      progress: 0,
      title: 'intro',
      detail: 'waiting',
      log: List.of(_log),
      backupItems: _backupItemsForDecision(),
    );
  }

  Future<File> backupTo(
    Directory selectedDirectory, {
    bool includeChatsJson = true,
  }) async {
    await selectedDirectory.create(recursive: true);
    final backupFile = File(p.join(selectedDirectory.path, backupFileName()));
    return _backupToFile(
      backupFile,
      includeChatsJson: includeChatsJson,
      visibleBackupPath: backupFile.path,
    );
  }

  Future<File> backupToTemporaryFile({bool includeChatsJson = true}) async {
    final backupFile = File(
      p.join(Directory.systemTemp.path, backupFileName()),
    );
    return _backupToFile(
      backupFile,
      includeChatsJson: includeChatsJson,
      visibleBackupPath: backupFile.path,
    );
  }

  /// Streams a ZIP to a platform-owned destination with bounded memory.
  /// The caller owns committing or discarding that destination.
  Future<void> backupToWritableSink(
    MigrationBackupChunkWriter writeChunk, {
    bool includeChatsJson = true,
  }) {
    return _backupToDestination(
      createOutput: () async => _MigrationZipOutput.toSink(writeChunk),
      includeChatsJson: includeChatsJson,
      managedOutputFile: null,
      visibleBackupPath: null,
    );
  }

  String backupFileName() {
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return 'kelivo_migration_backup_$timestamp.zip';
  }

  Future<File> _backupToFile(
    File backupFile, {
    required bool includeChatsJson,
    required String? visibleBackupPath,
  }) async {
    await _backupToDestination(
      createOutput: () => _MigrationZipOutput.openFile(backupFile.path),
      includeChatsJson: includeChatsJson,
      managedOutputFile: backupFile,
      visibleBackupPath: visibleBackupPath,
    );
    return backupFile;
  }

  Future<void> _backupToDestination({
    required Future<_MigrationZipOutput> Function() createOutput,
    required bool includeChatsJson,
    required File? managedOutputFile,
    required String? visibleBackupPath,
  }) async {
    Directory? workDir;
    _chatsExportDegraded = false;
    final plannedItems = _updateBackupItem(
      _backupItemsForDecision(includeChatsJson: includeChatsJson),
      _settingsBackupName,
      state: HiveToSqliteBackupItemState.active,
    );
    _lastBackupItems = plannedItems;
    var copiedBytes = 0;
    var totalBytes = 0;
    var lastProgress = 0.0;
    _emit(
      HiveToSqliteMigrationStage.backingUp,
      0,
      'backup',
      _settingsBackupName,
      backupPath: visibleBackupPath,
      backupItems: plannedItems,
    );

    _MigrationZipWriter? writer;
    try {
      await decision.appDataDir.create(recursive: true);
      workDir = await decision.appDataDir.createTemp(
        '.kelivo_migration_backup_',
      );
      final manifest = await _buildBackupManifest(
        workDir,
        visibleBackupPath,
        plannedItems,
      );
      _lastBackupItems = manifest.items;
      totalBytes = manifest.totalBytes;

      if (managedOutputFile != null) {
        await managedOutputFile.parent.create(recursive: true);
        if (await managedOutputFile.exists()) {
          await managedOutputFile.delete();
        }
      }
      writer = _MigrationZipWriter(
        await createOutput(),
        zip64Threshold: debugZip64ThresholdForTest,
      );
      for (final entry in manifest.entries) {
        final name = entry.itemName;
        _lastBackupItems = _updateBackupItem(
          _lastBackupItems,
          name,
          bytes: entry.itemBytes,
          state: HiveToSqliteBackupItemState.active,
        );
        lastProgress = _backupFileProgress(
          copiedBytes,
          totalBytes,
          includeChatsJson: includeChatsJson,
        );
        _emit(
          HiveToSqliteMigrationStage.backingUp,
          lastProgress,
          'backup',
          entry.entryName,
          backupPath: visibleBackupPath,
          backupItems: _lastBackupItems,
        );
        final written = await writer.addFile(
          entry.file,
          entry.entryName,
          onProgress: (fileWritten) {
            final currentTotal = copiedBytes + fileWritten;
            _lastBackupItems = _updateBackupItem(
              _lastBackupItems,
              name,
              bytes: entry.itemBytes,
              writtenBytes: entry.itemStartBytes + fileWritten,
              state: HiveToSqliteBackupItemState.active,
            );
            lastProgress = _backupFileProgress(
              currentTotal,
              totalBytes,
              includeChatsJson: includeChatsJson,
            );
            _emit(
              HiveToSqliteMigrationStage.backingUp,
              lastProgress,
              'backup',
              entry.entryName,
              backupPath: visibleBackupPath,
              backupItems: _lastBackupItems,
            );
          },
        );
        copiedBytes += written;
        final itemWritten = entry.itemStartBytes + written;
        final itemDone = itemWritten >= entry.itemBytes;
        _lastBackupItems = _updateBackupItem(
          _lastBackupItems,
          name,
          bytes: entry.itemBytes,
          writtenBytes: itemWritten,
          state: itemDone
              ? HiveToSqliteBackupItemState.done
              : HiveToSqliteBackupItemState.active,
        );
      }

      if (includeChatsJson) {
        File? chatsFile;
        try {
          chatsFile = await _exportLegacyChatsToFile(
            workDir,
            onProgress: (progress) {
              lastProgress = 0.78 + progress.clamp(0, 1) * 0.12;
              _lastBackupItems = _updateBackupItem(
                _lastBackupItems,
                _chatsBackupName,
                state: HiveToSqliteBackupItemState.active,
              );
              _emit(
                HiveToSqliteMigrationStage.backingUp,
                lastProgress,
                'backup',
                _chatsBackupName,
                backupPath: visibleBackupPath,
                backupItems: _lastBackupItems,
              );
            },
          );
        } catch (error, stackTrace) {
          // Raw Hive entries are already complete, so this convenience export
          // can degrade without weakening the disaster-recovery backup.
          _chatsExportDegraded = true;
          _logLine('chats.json export skipped: $error');
          _logLine(stackTrace.toString());
          _lastBackupItems = [
            for (final item in _lastBackupItems)
              if (item.name != _chatsBackupName) item,
          ];
        }
        if (chatsFile != null) {
          final chatsBytes = await chatsFile.length();
          totalBytes += chatsBytes;
          _lastBackupItems = _updateBackupItem(
            _lastBackupItems,
            _chatsBackupName,
            bytes: chatsBytes,
            writtenBytes: 0,
            state: HiveToSqliteBackupItemState.active,
          );
          final written = await writer.addFile(
            chatsFile,
            _chatsBackupName,
            onProgress: (fileWritten) {
              lastProgress = chatsBytes == 0
                  ? 1
                  : 0.9 + (fileWritten / chatsBytes).clamp(0, 1) * 0.1;
              _lastBackupItems = _updateBackupItem(
                _lastBackupItems,
                _chatsBackupName,
                bytes: chatsBytes,
                writtenBytes: fileWritten,
                state: HiveToSqliteBackupItemState.active,
              );
              _emit(
                HiveToSqliteMigrationStage.backingUp,
                lastProgress,
                'backup',
                _chatsBackupName,
                backupPath: visibleBackupPath,
                backupItems: _lastBackupItems,
              );
            },
          );
          copiedBytes += written;
          _lastBackupItems = _updateBackupItem(
            _lastBackupItems,
            _chatsBackupName,
            bytes: chatsBytes,
            writtenBytes: written,
            state: HiveToSqliteBackupItemState.done,
          );
        }
      }
      await writer.close();
    } catch (error, stackTrace) {
      _logLine('$error');
      _logLine(stackTrace.toString());
      try {
        await writer?.closeIfNeeded();
      } catch (_) {
        // Preserve the backup error; destination cleanup is best-effort.
      }
      if (managedOutputFile != null && await managedOutputFile.exists()) {
        await managedOutputFile.delete();
      }
      _controller.add(
        HiveToSqliteMigrationStatus(
          stage: HiveToSqliteMigrationStage.failed,
          progress: lastProgress.clamp(0, 1).toDouble(),
          title: 'failed',
          detail: 'backup',
          error: '$error',
          log: List.of(_log),
          converted: _converted,
          malformed: _malformed,
          missingFiles: _missingFiles,
          backupItems: _lastBackupItems,
          chatsExportDegraded: _chatsExportDegraded,
        ),
      );
      rethrow;
    } finally {
      await writer?.closeIfNeeded();
      await _deleteDirectoryQuietly(workDir);
    }

    _emit(
      HiveToSqliteMigrationStage.backupReady,
      1,
      'backup',
      'done',
      backupPath: visibleBackupPath,
      backupItems: _lastBackupItems,
    );
  }

  Future<void> migrate({String? backupPath}) async {
    ChatDatabaseRepository? repo;
    LazyBox<Conversation>? conversationsBox;
    LazyBox<ChatMessage>? messagesBox;
    LazyBox<dynamic>? toolEventsBox;
    var published = false;
    try {
      // Bind canonicalize to this process's app data root (refresh even if a
      // previous test/session left docsDir pointing elsewhere).
      await SandboxPathResolver.init();
      await _beginAttempt();
      await _recordStageBreadcrumb(
        HiveToSqliteMigrationStage.migrating,
        'schema',
      );
      _emit(
        HiveToSqliteMigrationStage.migrating,
        0,
        'migrate',
        'schema',
        backupPath: backupPath,
        backupItems: _lastBackupItems,
      );
      _registerHiveAdapters();
      await Hive.initFlutter(decision.appDataDir.path);
      conversationsBox = await Hive.openLazyBox<Conversation>(
        _conversationBoxName,
      );
      messagesBox = await Hive.openLazyBox<ChatMessage>(_messagesBoxName);
      final hasToolEventsBox = decision.hiveFiles.any(
        (file) => p.basename(file.path) == 'tool_events_v1.hive',
      );
      if (hasToolEventsBox) {
        toolEventsBox = await Hive.openLazyBox<dynamic>(_toolEventsBoxName);
      }

      final tempFile = File('${decision.sqliteFile.path}.migrating');
      await _deleteSqliteFamily(tempFile);
      repo = ChatDatabaseRepository.open(file: tempFile);

      // 1.1.17 tolerated dangling references, cross-conversation reuse and
      // duplicate (groupId, version) pairs at runtime; the batches must repair
      // or skip those shapes instead of failing the whole migration.
      final repairStats = _MigrationRepairStats();
      final conversations = <Conversation>[];
      for (final key in conversationsBox.keys) {
        try {
          assert(() {
            if (debugFailConversationKeysForTest.contains('$key')) {
              throw StateError('debug_forced_conversation_decode_failure');
            }
            return true;
          }());
          final conversation = await conversationsBox.get(key);
          if (conversation != null) conversations.add(conversation);
        } catch (error, stackTrace) {
          // A conversation record that cannot be deserialized must cost only
          // that conversation, not the whole migration. The Hive source is
          // retained, so nothing is destroyed.
          repairStats.undecodableConversations++;
          _logLine('legacy-conversation skipped ($key): $error');
          _logLine(stackTrace.toString());
        }
      }
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final totalMessages = conversations.fold<int>(
        0,
        (sum, conversation) => sum + conversation.messageIds.length,
      );
      var migratedMessages = 0;
      var expectedToolCallParts = 0;
      var expectedImageParts = 0;
      var expectedFileParts = 0;
      _converted = 0;
      _malformed = 0;
      _missingFiles = 0;
      final expectedTextContentDigest = Uint8List(32);
      _emit(
        HiveToSqliteMigrationStage.migrating,
        0.04,
        'migrate',
        'schema',
        backupPath: backupPath,
        backupItems: _lastBackupItems,
        conversations: conversations.length,
        messages: totalMessages,
      );

      await repo.clearAllData();
      final seenMessageIds = <String>{};
      await _recordStageBreadcrumb(
        HiveToSqliteMigrationStage.migrating,
        'messages',
      );
      for (final legacyConversation in conversations) {
        final conversation = _sanitizeLegacyConversationFields(
          await _convertLegacyVersionSelections(
            await _convertLegacyTruncateIndex(
              legacyConversation,
              messagesBox,
              seenMessageIds,
            ),
            messagesBox,
            seenMessageIds,
          ),
          repairStats,
        );
        var needsConversationInsert = true;
        var order = 0;
        final seenGroupVersions = <String>{};
        final maxGroupVersions = <String, int>{};
        for (
          var start = 0;
          start < conversation.messageIds.length;
          start += _messageBatchSize
        ) {
          final end = (start + _messageBatchSize)
              .clamp(start, conversation.messageIds.length)
              .toInt();
          final batch = <({ChatMessage message, int messageOrder})>[];
          final toolEventsByMessageId = <String, List<Map<String, dynamic>>>{};
          final geminiSignaturesByMessageId = <String, String>{};
          for (var i = start; i < end; i++) {
            final messageId = conversation.messageIds[i];
            try {
              var message = await messagesBox.get(messageId);
              if (message == null) {
                repairStats.danglingMessageRefs++;
                continue;
              }
              assert(() {
                if (debugFailMessageIdsForTest.contains(message!.id)) {
                  throw StateError('debug_forced_decode_failure');
                }
                return true;
              }());
              if (!seenMessageIds.add(message.id)) {
                repairStats.duplicateMessageIds++;
                continue;
              }
              if (message.conversationId != conversation.id) {
                repairStats.conversationIdMismatches++;
                message = message.copyWith(conversationId: conversation.id);
              }
              // Field-level repair (empty role, negative tokens/duration,
              // out-of-range version, inverted reasoning timestamps) shares
              // logic with the chats.json import boundary.
              final sanitized = sanitizeLegacyMessageFields(message);
              if (!identical(sanitized, message)) {
                repairStats.dirtyNumericFields++;
                message = sanitized;
              }
              final groupId = message.groupId;
              // '' is stored verbatim and is a real value to the
              // unique(conversationId, groupId, version) index (unlike NULL),
              // so empty-string groups need version repair too.
              if (groupId != null) {
                var version = message.version;
                if (!seenGroupVersions.add('$groupId\u0000$version')) {
                  version = (maxGroupVersions[groupId] ?? version) + 1;
                  repairStats.versionConflicts++;
                  message = message.copyWith(version: version);
                  seenGroupVersions.add('$groupId\u0000$version');
                }
                final knownMax = maxGroupVersions[groupId];
                if (knownMax == null || version > knownMax) {
                  maxGroupVersions[groupId] = version;
                }
              }
              final legacyContent = message.content;
              final decodeResult = await decodeLegacyContent(
                legacyContent,
                existingParts: message.parts,
              );
              var parts = List<MessagePart>.of(decodeResult.parts);
              if (parts.isEmpty) {
                // Match repository persistence: empty body becomes one empty
                // text part.
                parts = const <MessagePart>[TextPart('')];
              }
              parts = _normalizeAttachmentPartUris(parts);
              message = message.copyWith(parts: parts);
              // Expected digest comes from independently stripped legacy text,
              // not merely echoing decoder TextPart objects. Compute it before
              // committing so a strip failure skips the message cleanly.
              final textSegments = stripLegacyContentTextSegments(
                legacyContent,
              );
              List<Map<String, dynamic>>? events;
              String? signature;
              if (toolEventsBox != null) {
                final gathered = await _toolEventsFor(
                  toolEventsBox,
                  message.id,
                );
                if (gathered.isNotEmpty) events = gathered;
                signature = await _signatureFor(toolEventsBox, message.id);
              }

              // Commit only after every fallible step succeeded, so a message
              // that threw above is skipped entirely and never contributes to
              // the batch, the expected counts, or the digest. The batch write
              // itself stays outside this try: a DB failure must fail loudly.
              _converted += decodeResult.converted;
              _malformed += decodeResult.malformed;
              _missingFiles += decodeResult.missingFiles;
              expectedImageParts += parts.whereType<ImagePart>().length;
              expectedFileParts += parts.whereType<FilePart>().length;
              batch.add((message: message, messageOrder: order));
              order++;
              for (final segment in textSegments) {
                ChatDatabaseRepository.mixTextPartContentDigest(
                  expectedTextContentDigest,
                  message.id,
                  segment,
                );
              }
              if (events != null) {
                toolEventsByMessageId[message.id] = events;
                expectedToolCallParts += events.length;
              }
              if (signature != null) {
                geminiSignaturesByMessageId[message.id] = signature;
              }
            } catch (error, stackTrace) {
              // A single corrupt/undecodable legacy record must not sink the
              // whole migration. Skip it, count it, and keep going; the Hive
              // source is retained so nothing is destroyed.
              repairStats.decodeFailures++;
              _logLine('legacy-message skipped ($messageId): $error');
              _logLine(stackTrace.toString());
            }
          }
          await repo.putMigrationBatch(
            conversations: needsConversationInsert
                ? [conversation]
                : const <Conversation>[],
            messages: batch,
            toolEventsByMessageId: toolEventsByMessageId,
            geminiSignaturesByMessageId: geminiSignaturesByMessageId,
          );
          needsConversationInsert = false;
          migratedMessages += batch.length;
          final messageProgress = totalMessages == 0
              ? 0.9
              : 0.04 + (migratedMessages / totalMessages) * 0.86;
          _emit(
            HiveToSqliteMigrationStage.migrating,
            messageProgress,
            'migrate',
            'messages',
            backupPath: backupPath,
            backupItems: _lastBackupItems,
            conversations: conversations.length,
            messages: migratedMessages,
          );
          await Future<void>.delayed(Duration.zero);
        }
        if (needsConversationInsert) {
          await repo.putMigrationBatch(
            conversations: [conversation],
            messages: const <({ChatMessage message, int messageOrder})>[],
            toolEventsByMessageId: const <String, List<Map<String, dynamic>>>{},
            geminiSignaturesByMessageId: const <String, String>{},
          );
        }
      }
      if (repairStats.hasIssues) {
        _logLine('legacy-data repairs: ${repairStats.describe()}');
      }

      await _recordStageBreadcrumb(
        HiveToSqliteMigrationStage.migrating,
        'tool_events',
      );
      _emit(
        HiveToSqliteMigrationStage.migrating,
        0.94,
        'migrate',
        'tool_events',
        backupPath: backupPath,
        backupItems: _lastBackupItems,
        conversations: conversations.length,
        messages: migratedMessages,
      );
      await _recordStageBreadcrumb(
        HiveToSqliteMigrationStage.migrating,
        'validate',
      );
      _emit(
        HiveToSqliteMigrationStage.migrating,
        0.98,
        'migrate',
        'validate',
        backupPath: backupPath,
        backupItems: _lastBackupItems,
        conversations: conversations.length,
        messages: migratedMessages,
      );
      final beforeValidate = debugBeforeValidateForTest;
      if (beforeValidate != null) {
        await beforeValidate(repo);
      }
      _logLine(
        'legacy-content decode: converted=$_converted '
        'malformed=$_malformed missingFiles=$_missingFiles',
      );
      await _validate(
        repo,
        expectedConversations: conversations.length,
        expectedMessages: migratedMessages,
        expectedTextContentDigest:
            ChatDatabaseRepository.textPartContentDigestHex(
              expectedTextContentDigest,
            ),
        expectedToolCallParts: expectedToolCallParts,
        expectedImageParts: expectedImageParts,
        expectedFileParts: expectedFileParts,
        backupPath: backupPath,
        migratedMessages: migratedMessages,
      );
      await repo.markMigrationComplete();
      await repo.checkpoint();
      await repo.close();
      repo = null;
      // WAL truncate can leave empty -wal/-shm files behind; strip them before
      // the publish assertion treats any sidecar as unexpected data loss.
      await _deleteDatabaseSidecars(tempFile);

      await _recordStageBreadcrumb(
        HiveToSqliteMigrationStage.migrating,
        'publish',
      );
      await _replaceSqlite(tempFile, decision.sqliteFile);
      published = true;
      await _clearAttemptState();
      _emit(
        HiveToSqliteMigrationStage.complete,
        1,
        'complete',
        'done',
        backupPath: backupPath,
        backupItems: _lastBackupItems,
        conversations: conversations.length,
        messages: migratedMessages,
      );
    } catch (error, stackTrace) {
      _logLine('$error');
      _logLine(stackTrace.toString());
      _controller.add(
        HiveToSqliteMigrationStatus(
          stage: HiveToSqliteMigrationStage.failed,
          progress: 0,
          title: 'failed',
          detail: 'failed',
          backupPath: backupPath,
          error: '$error',
          log: List.of(_log),
          converted: _converted,
          malformed: _malformed,
          missingFiles: _missingFiles,
          backupItems: _lastBackupItems,
          chatsExportDegraded: _chatsExportDegraded,
        ),
      );
      rethrow;
    } finally {
      await repo?.close();
      await conversationsBox?.close();
      await messagesBox?.close();
      await toolEventsBox?.close();
      if (!published) {
        // A failed attempt must not leave the half-migrated database family
        // behind; the startup gate would otherwise keep rejecting it.
        await _deleteSqliteFamily(
          File('${decision.sqliteFile.path}.migrating'),
        );
      }
    }
  }

  /// Delegates to the shared legacy sanitizer and counts repairs in the
  /// migration stats. Out-of-range counters in dirty Hive data would
  /// otherwise abort the whole migration with SQLITE_CONSTRAINT_CHECK.
  Conversation _sanitizeLegacyConversationFields(
    Conversation conversation,
    _MigrationRepairStats stats,
  ) {
    final sanitized = sanitizeLegacyConversationFields(conversation);
    if (!identical(sanitized, conversation)) {
      stats.dirtyNumericFields++;
    }
    return sanitized;
  }

  /// Prescan-safe message read: an undecodable record is treated like a
  /// dangling reference instead of aborting the migration. The same record
  /// is read again by the main loop, where the failure is counted once in
  /// the repair stats.
  Future<ChatMessage?> _tryGetLegacyMessage(
    LazyBox<ChatMessage> messagesBox,
    String messageId,
  ) async {
    try {
      assert(() {
        if (debugFailPrescanMessageIdsForTest.contains(messageId)) {
          throw StateError('debug_forced_prescan_decode_failure');
        }
        return true;
      }());
      return await messagesBox.get(messageId);
    } catch (error) {
      _logLine('legacy-message prescan read failed ($messageId): $error');
      return null;
    }
  }

  Future<Conversation> _convertLegacyTruncateIndex(
    Conversation conversation,
    LazyBox<ChatMessage> messagesBox,
    Set<String> alreadyMigratedMessageIds,
  ) async {
    final truncateIndex = conversation.truncateIndex;
    if (truncateIndex < 0 || truncateIndex > conversation.messageIds.length) {
      return conversation;
    }

    final groupsBeforeTruncate = <String>{};
    for (var i = 0; i < truncateIndex; i++) {
      final message = await _tryGetLegacyMessage(
        messagesBox,
        conversation.messageIds[i],
      );
      if (message == null || alreadyMigratedMessageIds.contains(message.id)) {
        continue;
      }
      groupsBeforeTruncate.add(message.groupId ?? message.id);
    }
    final logicalIndex = groupsBeforeTruncate.length;
    return logicalIndex == truncateIndex
        ? conversation
        : conversation.copyWith(truncateIndex: logicalIndex);
  }

  Future<Conversation> _convertLegacyVersionSelections(
    Conversation conversation,
    LazyBox<ChatMessage> messagesBox,
    Set<String> alreadyMigratedMessageIds,
  ) async {
    if (conversation.versionSelections.isEmpty) return conversation;

    final messagesByGroup = <String, List<ChatMessage>>{
      for (final groupId in conversation.versionSelections.keys)
        groupId: <ChatMessage>[],
    };
    final repairedVersionsByMessageId = <String, int>{};
    final localMessageIds = <String>{};
    final seenGroupVersions = <String>{};
    final maxGroupVersions = <String, int>{};
    for (final messageId in conversation.messageIds) {
      final message = await _tryGetLegacyMessage(messagesBox, messageId);
      if (message == null) continue;
      messagesByGroup[message.groupId ?? message.id]?.add(message);
      if (alreadyMigratedMessageIds.contains(message.id) ||
          !localMessageIds.add(message.id)) {
        continue;
      }

      final groupId = message.groupId;
      if (groupId == null) continue;
      var repairedVersion = message.version;
      if (!seenGroupVersions.add('$groupId\u0000$repairedVersion')) {
        repairedVersion = (maxGroupVersions[groupId] ?? repairedVersion) + 1;
        repairedVersionsByMessageId[message.id] = repairedVersion;
        seenGroupVersions.add('$groupId\u0000$repairedVersion');
      }
      final knownMax = maxGroupVersions[groupId];
      if (knownMax == null || repairedVersion > knownMax) {
        maxGroupVersions[groupId] = repairedVersion;
      }
    }

    final convertedSelections = Map<String, int>.from(
      conversation.versionSelections,
    );
    var changed = false;
    for (final entry in conversation.versionSelections.entries) {
      final messages = messagesByGroup[entry.key]!
        ..sort((left, right) => left.version.compareTo(right.version));
      if (messages.isEmpty) continue;
      final ordinal = entry.value;
      final selectedMessage = ordinal >= 0 && ordinal < messages.length
          ? messages[ordinal]
          : messages.last;
      final version =
          repairedVersionsByMessageId[selectedMessage.id] ??
          selectedMessage.version;
      if (version != ordinal) {
        convertedSelections[entry.key] = version;
        changed = true;
      }
    }

    return changed
        ? conversation.copyWith(versionSelections: convertedSelections)
        : conversation;
  }

  /// Escape hatch after repeated migration failures: renames the legacy Hive
  /// artifacts to `<name>.retired` so [check] stops requesting migration and
  /// the next launch starts with an empty SQLite database. The retired files
  /// stay on disk for manual recovery.
  Future<void> skipMigrationAndStartFresh() async {
    for (final hiveFile in decision.hiveFiles) {
      final lockFile = File('${p.withoutExtension(hiveFile.path)}.lock');
      try {
        if (await lockFile.exists()) {
          await lockFile.rename('${lockFile.path}.retired');
        }
      } catch (error) {
        // Lock files are advisory; leaving one behind must not block the skip.
        _logLine('skip-migration lock rename: $error');
      }
      if (await hiveFile.exists()) {
        await hiveFile.rename('${hiveFile.path}.retired');
      }
    }
    // A failed attempt can leave the temporary database family behind.
    await _deleteSqliteFamily(File('${decision.sqliteFile.path}.migrating'));
    await _deleteSqliteFamily(File('${decision.sqliteFile.path}.previous'));
    await _clearAttemptState();
    _logLine('skip-migration: legacy hive files retired');
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  List<HiveToSqliteBackupItem> _backupItemsForDecision({
    bool includeChatsJson = true,
  }) {
    return [
      const HiveToSqliteBackupItem(name: _settingsBackupName, bytes: 0),
      if (includeChatsJson)
        const HiveToSqliteBackupItem(name: _chatsBackupName, bytes: 0),
      for (final file in decision.hiveFiles)
        HiveToSqliteBackupItem(name: p.basename(file.path), bytes: 0),
      for (final directory in _backupDirectories)
        if (_backupDirectoryMayContainFiles(directory.directoryName))
          HiveToSqliteBackupItem(name: '${directory.zipPrefix}/', bytes: 0),
    ];
  }

  bool _backupDirectoryMayContainFiles(String directoryName) {
    final directory = Directory(
      p.join(decision.appDataDir.path, directoryName),
    );
    try {
      if (!directory.existsSync()) return false;
      return directory.listSync(followLinks: false).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<_MigrationBackupManifest> _buildBackupManifest(
    Directory workDir,
    String? backupPath,
    List<HiveToSqliteBackupItem> plannedItems,
  ) async {
    final files = <_MigrationBackupFile>[];
    var items = plannedItems;

    items = _updateBackupItem(
      items,
      _settingsBackupName,
      state: HiveToSqliteBackupItemState.active,
    );
    _emit(
      HiveToSqliteMigrationStage.backingUp,
      0.02,
      'backup',
      _settingsBackupName,
      backupPath: backupPath,
      backupItems: items,
    );
    final settingsJson = await _exportSettingsJson();
    final settingsFile = await _writeTempText(
      workDir,
      '_migration_settings.json',
      settingsJson,
    );
    final settingsBytes = await settingsFile.length();
    items = _updateBackupItem(
      items,
      _settingsBackupName,
      bytes: settingsBytes,
      writtenBytes: settingsBytes,
      state: HiveToSqliteBackupItemState.done,
    );
    _lastBackupItems = items;
    files.add(
      _MigrationBackupFile(
        file: settingsFile,
        entryName: _settingsBackupName,
        itemName: _settingsBackupName,
        bytes: settingsBytes,
      ),
    );

    for (final hiveFile in decision.hiveFiles) {
      final itemName = p.basename(hiveFile.path);
      // The writer consumes these entries before chats.json opens Hive. This
      // preserves the original bytes without a second multi-gigabyte copy.
      final bytes = await hiveFile.length();
      items = _updateBackupItem(items, itemName, bytes: bytes);
      _lastBackupItems = items;
      _emit(
        HiveToSqliteMigrationStage.backingUp,
        0.13,
        'backup',
        itemName,
        backupPath: backupPath,
        backupItems: items,
      );
      files.add(
        _MigrationBackupFile(
          file: hiveFile,
          entryName: itemName,
          itemName: itemName,
          bytes: bytes,
        ),
      );
    }

    for (final directory in _backupDirectories) {
      final source = Directory(
        p.join(decision.appDataDir.path, directory.directoryName),
      );
      final itemName = '${directory.zipPrefix}/';
      if (!items.any((item) => item.name == itemName)) continue;
      items = _updateBackupItem(
        items,
        itemName,
        state: HiveToSqliteBackupItemState.active,
      );
      _lastBackupItems = items;
      _emit(
        HiveToSqliteMigrationStage.backingUp,
        0.13,
        'backup',
        itemName,
        backupPath: backupPath,
        backupItems: items,
      );
      final directoryFiles = await _filesInDirectory(
        source,
        directory.zipPrefix,
        itemName,
        onProgress: (bytes) {
          items = _updateBackupItem(
            items,
            itemName,
            bytes: bytes,
            state: HiveToSqliteBackupItemState.active,
          );
          _lastBackupItems = items;
          _emit(
            HiveToSqliteMigrationStage.backingUp,
            0.13,
            'backup',
            itemName,
            backupPath: backupPath,
            backupItems: items,
          );
        },
      );
      if (directoryFiles.isEmpty) {
        items = _updateBackupItem(
          items,
          itemName,
          bytes: 0,
          state: HiveToSqliteBackupItemState.done,
        );
        _lastBackupItems = items;
        _emit(
          HiveToSqliteMigrationStage.backingUp,
          0.13,
          'backup',
          itemName,
          backupPath: backupPath,
          backupItems: items,
        );
        continue;
      }
      final bytes = directoryFiles.fold<int>(
        0,
        (sum, file) => sum + file.bytes,
      );
      items = _updateBackupItem(items, itemName, bytes: bytes);
      _lastBackupItems = items;
      _emit(
        HiveToSqliteMigrationStage.backingUp,
        0.13,
        'backup',
        itemName,
        backupPath: backupPath,
        backupItems: items,
      );
      files.addAll(directoryFiles);
    }

    final itemBytes = <String, int>{};
    for (final item in items) {
      itemBytes[item.name] = item.bytes;
    }
    final itemWritten = <String, int>{};
    final entries = <_MigrationBackupFileEntry>[];
    for (final file in files) {
      final startBytes = itemWritten[file.itemName] ?? 0;
      entries.add(
        _MigrationBackupFileEntry(
          file: file.file,
          entryName: file.entryName,
          itemName: file.itemName,
          bytes: file.bytes,
          itemBytes: itemBytes[file.itemName] ?? file.bytes,
          itemStartBytes: startBytes,
        ),
      );
      itemWritten[file.itemName] = startBytes + file.bytes;
    }

    return _MigrationBackupManifest(
      entries: entries,
      items: [
        for (final item in items)
          item.copyWith(
            writtenBytes: 0,
            state: HiveToSqliteBackupItemState.pending,
          ),
      ],
      totalBytes: files.fold<int>(0, (sum, file) => sum + file.bytes),
    );
  }

  List<HiveToSqliteBackupItem> _updateBackupItem(
    List<HiveToSqliteBackupItem> items,
    String name, {
    int? bytes,
    int? writtenBytes,
    HiveToSqliteBackupItemState? state,
  }) {
    return [
      for (final item in items)
        if (item.name == name)
          item.copyWith(bytes: bytes, writtenBytes: writtenBytes, state: state)
        else
          item,
    ];
  }

  Future<List<_MigrationBackupFile>> _filesInDirectory(
    Directory directory,
    String zipPrefix,
    String itemName, {
    required void Function(int bytes) onProgress,
  }) async {
    if (!await directory.exists()) return const <_MigrationBackupFile>[];
    final files = <_MigrationBackupFile>[];
    var totalBytes = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relative = p
          .relative(entity.path, from: directory.path)
          .replaceAll('\\', '/');
      final bytes = await entity.length();
      files.add(
        _MigrationBackupFile(
          file: entity,
          entryName: _zipEntryName('$zipPrefix/$relative'),
          itemName: itemName,
          bytes: bytes,
        ),
      );
      totalBytes += bytes;
      if (files.length == 1 || files.length % 40 == 0) {
        onProgress(totalBytes);
        await Future<void>.delayed(Duration.zero);
      }
    }
    onProgress(totalBytes);
    files.sort((a, b) => a.entryName.compareTo(b.entryName));
    return files;
  }

  Future<String> _exportSettingsJson() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, Object>{};
    for (final key in prefs.getKeys()) {
      if (BackupSettingsValidator.shouldIgnore(key) &&
          !_legacyBusinessKeysNeededForRecovery.contains(key)) {
        continue;
      }
      final value = prefs.get(key);
      if (value != null) map[key] = value;
    }
    return jsonEncode(map);
  }

  Future<File> _writeTempText(
    Directory directory,
    String name,
    String content,
  ) async {
    final file = File(p.join(directory.path, name));
    await file.writeAsString(content);
    return file;
  }

  Future<File> _exportLegacyChatsToFile(
    Directory directory, {
    required void Function(double progress) onProgress,
  }) async {
    _registerHiveAdapters();
    await Hive.initFlutter(decision.appDataDir.path);
    LazyBox<Conversation>? conversationsBox;
    LazyBox<ChatMessage>? messagesBox;
    LazyBox<dynamic>? toolEventsBox;
    final file = File(p.join(directory.path, '_migration_chats.json'));
    final hasMessagesBox = decision.hiveFiles.any(
      (file) => p.basename(file.path) == 'messages.hive',
    );
    final hasToolEventsBox = decision.hiveFiles.any(
      (file) => p.basename(file.path) == 'tool_events_v1.hive',
    );

    try {
      conversationsBox = await Hive.openLazyBox<Conversation>(
        _conversationBoxName,
      );
      if (hasMessagesBox) {
        messagesBox = await Hive.openLazyBox<ChatMessage>(_messagesBoxName);
      }
      if (hasToolEventsBox) {
        toolEventsBox = await Hive.openLazyBox<dynamic>(_toolEventsBoxName);
      }

      final conversationKeys = conversationsBox.keys.toList(growable: false);
      final sink = file.openWrite();
      var messageRefs = 0;
      try {
        sink.write('{"version":1,');
        sink.write('"conversations":[');
        var firstConversation = true;
        var processedConversations = 0;
        for (final key in conversationKeys) {
          final conversation = await conversationsBox.get(key);
          if (conversation == null) continue;
          if (!firstConversation) sink.write(',');
          firstConversation = false;
          sink.write(jsonEncode(conversation.toJson()));
          messageRefs += conversation.messageIds.length;
          processedConversations++;
          if (processedConversations % 20 == 0) {
            final progress = conversationKeys.isEmpty
                ? 0.25
                : (processedConversations / conversationKeys.length) * 0.25;
            onProgress(progress);
            await Future<void>.delayed(Duration.zero);
          }
        }
        sink.write('],');
        onProgress(0.25);

        var messageWork = 0;
        final messagePassWork = messageRefs == 0 ? 1 : messageRefs * 3;
        double messageProgress() =>
            0.25 + (messageWork / messagePassWork).clamp(0, 1) * 0.75;

        sink.write('"messages":[');
        var firstMessage = true;
        if (messagesBox != null) {
          for (final key in conversationKeys) {
            final conversation = await conversationsBox.get(key);
            if (conversation == null) continue;
            for (final messageId in conversation.messageIds) {
              final message = await messagesBox.get(messageId);
              if (message != null) {
                if (!firstMessage) sink.write(',');
                firstMessage = false;
                // Legacy chats backup must stay parts-free so restore paths
                // that only understand content/markers remain compatible.
                final json = message.toJson();
                json.remove('parts');
                sink.write(jsonEncode(json));
              }
              messageWork++;
              if (messageWork % 64 == 0) {
                onProgress(messageProgress());
                await Future<void>.delayed(Duration.zero);
              }
            }
          }
        }
        sink.write('],');

        sink.write('"toolEvents":{');
        var firstToolEvents = true;
        if (toolEventsBox != null) {
          for (final key in conversationKeys) {
            final conversation = await conversationsBox.get(key);
            if (conversation == null) continue;
            for (final messageId in conversation.messageIds) {
              final events = await _toolEventsFor(toolEventsBox, messageId);
              if (events.isNotEmpty) {
                if (!firstToolEvents) sink.write(',');
                firstToolEvents = false;
                sink.write(jsonEncode(messageId));
                sink.write(':');
                sink.write(jsonEncode(events));
              }
              messageWork++;
              if (messageWork % 64 == 0) {
                onProgress(messageProgress());
                await Future<void>.delayed(Duration.zero);
              }
            }
          }
        }
        sink.write('},');

        sink.write('"geminiThoughtSigs":{');
        var firstSignature = true;
        if (toolEventsBox != null) {
          for (final key in conversationKeys) {
            final conversation = await conversationsBox.get(key);
            if (conversation == null) continue;
            for (final messageId in conversation.messageIds) {
              final signature = await _signatureFor(toolEventsBox, messageId);
              if (signature != null) {
                if (!firstSignature) sink.write(',');
                firstSignature = false;
                sink.write(jsonEncode(messageId));
                sink.write(':');
                sink.write(jsonEncode(signature));
              }
              messageWork++;
              if (messageWork % 64 == 0) {
                onProgress(messageProgress());
                await Future<void>.delayed(Duration.zero);
              }
            }
          }
        }
        sink.write('}');
        sink.write('}');
      } finally {
        await sink.flush();
        await sink.close();
      }
      onProgress(1);
      return file;
    } finally {
      await toolEventsBox?.close();
      await messagesBox?.close();
      await conversationsBox?.close();
    }
  }

  double _backupFileProgress(
    int copiedBytes,
    int totalBytes, {
    required bool includeChatsJson,
  }) {
    final end = includeChatsJson ? 0.78 : 1.0;
    if (totalBytes <= 0) return end;
    return _backupPreparationShare +
        (copiedBytes / totalBytes) * (end - _backupPreparationShare);
  }

  static Future<void> _deleteDirectoryQuietly(Directory? directory) async {
    if (directory == null) return;
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {}
  }

  static String _zipEntryName(String name) {
    return name.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
  }

  Future<List<Map<String, dynamic>>> _toolEventsFor(
    LazyBox<dynamic> box,
    String messageId,
  ) async {
    final value = await box.get(messageId);
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  Future<String?> _signatureFor(LazyBox<dynamic> box, String messageId) async {
    final value = await box.get('sig_$messageId');
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  Future<void> _validate(
    ChatDatabaseRepository repo, {
    required int expectedConversations,
    required int expectedMessages,
    required String expectedTextContentDigest,
    required int expectedToolCallParts,
    required int expectedImageParts,
    required int expectedFileParts,
    String? backupPath,
    int migratedMessages = 0,
  }) async {
    final conversationCount = await repo.getConversationCount();
    if (conversationCount != expectedConversations) {
      throw StateError(
        'Migration validation failed (conversation count): '
        'expected $expectedConversations, got $conversationCount.',
      );
    }
    final messageCount = await repo.getTotalMessageCount();
    if (messageCount != expectedMessages) {
      throw StateError(
        'Migration validation failed (message count): '
        'expected $expectedMessages, got $messageCount.',
      );
    }
    final toolCallPartCount = await repo.getToolCallPartCount();
    if (toolCallPartCount != expectedToolCallParts) {
      throw StateError(
        'Migration validation failed (tool_call part count): '
        'expected $expectedToolCallParts, got $toolCallPartCount.',
      );
    }
    final imagePartCount = await repo.getImagePartCount();
    if (imagePartCount != expectedImageParts) {
      throw StateError(
        'Migration validation failed (image part count): '
        'expected $expectedImageParts, got $imagePartCount.',
      );
    }
    final filePartCount = await repo.getFilePartCount();
    if (filePartCount != expectedFileParts) {
      throw StateError(
        'Migration validation failed (file part count): '
        'expected $expectedFileParts, got $filePartCount.',
      );
    }
    var lastAttachmentProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
    await repo.validateAttachmentPartPayloads(
      onProgress: (processed, total) {
        final now = DateTime.now();
        final isDone = total > 0 && processed >= total;
        if (!isDone &&
            now.difference(lastAttachmentProgressEmit) <
                const Duration(milliseconds: 100)) {
          return;
        }
        lastAttachmentProgressEmit = now;
        final fraction = total <= 0 ? 1.0 : (processed / total).clamp(0.0, 1.0);
        _emit(
          HiveToSqliteMigrationStage.migrating,
          0.98 + 0.005 * fraction,
          'migrate',
          'validate',
          backupPath: backupPath,
          backupItems: _lastBackupItems,
          conversations: expectedConversations,
          messages: migratedMessages,
        );
      },
    );
    // Digest scans multi-GB payloads on a worker isolate; map byte progress
    // into the remaining validate window so the migration bar keeps moving.
    var lastDigestProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
    final textContentDigest = await repo.getTextPartContentDigest(
      onProgress: (processedChars, totalChars) {
        final now = DateTime.now();
        final isDone = totalChars > 0 && processedChars >= totalChars;
        if (!isDone &&
            now.difference(lastDigestProgressEmit) <
                const Duration(milliseconds: 100)) {
          return;
        }
        lastDigestProgressEmit = now;
        final fraction = totalChars <= 0
            ? 1.0
            : (processedChars / totalChars).clamp(0.0, 1.0);
        _emit(
          HiveToSqliteMigrationStage.migrating,
          0.985 + 0.01 * fraction,
          'migrate',
          'validate',
          backupPath: backupPath,
          backupItems: _lastBackupItems,
          conversations: expectedConversations,
          messages: migratedMessages,
        );
      },
    );
    if (textContentDigest != expectedTextContentDigest) {
      throw StateError(
        'Migration validation failed (text content digest): '
        'expected $expectedTextContentDigest, got $textContentDigest.',
      );
    }
  }

  @visibleForTesting
  Future<void> replaceSqliteForTest(File tempFile, File sqliteFile) {
    return _replaceSqlite(tempFile, sqliteFile);
  }

  Future<void> _replaceSqlite(File tempFile, File sqliteFile) async {
    final asideFile = File('${sqliteFile.path}.previous');
    final tempType = await FileSystemEntity.type(
      tempFile.path,
      followLinks: false,
    );
    final liveType = await FileSystemEntity.type(
      sqliteFile.path,
      followLinks: false,
    );

    if (tempType == FileSystemEntityType.notFound) {
      if (liveType != FileSystemEntityType.file) {
        throw StateError('migration_publish_missing_temp');
      }
      await _deleteDatabaseSidecars(sqliteFile);
      await _deleteSqliteFamily(asideFile);
      return;
    }
    if (tempType != FileSystemEntityType.file) {
      throw StateError('migration_publish_temp_not_file');
    }
    await _requireNoDatabaseSidecars(tempFile);

    if (liveType == FileSystemEntityType.directory) {
      throw StateError('migration_publish_live_not_file');
    }
    if (liveType == FileSystemEntityType.file) {
      await _deleteDatabaseSidecars(sqliteFile);
      await _deleteSqliteFamily(asideFile);
      await _durability.renameAndSync(
        source: sqliteFile,
        targetPath: asideFile.path,
      );
    }

    final liveAfterAside = await FileSystemEntity.type(
      sqliteFile.path,
      followLinks: false,
    );
    if (liveAfterAside == FileSystemEntityType.notFound) {
      await _durability.renameAndSync(
        source: tempFile,
        targetPath: sqliteFile.path,
      );
    } else if (await tempFile.exists()) {
      throw StateError('migration_publish_split_brain');
    }

    await _durability.syncDirectory(
      Directory(p.dirname(sqliteFile.path)),
      fullBarrier: true,
    );
    await _deleteSqliteFamily(asideFile);
  }

  Future<void> _requireNoDatabaseSidecars(File databaseFile) async {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final sidecar = File('${databaseFile.path}$suffix');
      if (await FileSystemEntity.type(sidecar.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('database_sidecar:$suffix');
      }
    }
  }

  Future<void> _deleteDatabaseSidecars(File databaseFile) async {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final sidecar = File('${databaseFile.path}$suffix');
      if (await FileSystemEntity.type(sidecar.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        await sidecar.delete();
      }
    }
  }

  Future<void> _deleteSqliteFamily(File file) =>
      _deleteSqliteFamilyStatic(file);

  static Future<void> _deleteSqliteFamilyStatic(File file) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final target = File('${file.path}$suffix');
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        await target.delete();
      }
    }
  }

  File get _attemptStateFile =>
      File(p.join(decision.appDataDir.path, _attemptStateFileName));

  Future<void> _beginAttempt() async {
    final state = await _readAttemptState();
    _attemptCount = state.attempts + 1;
    _persistedStageBreadcrumb = 'migrating/start';
    await _writeAttemptState(
      attempts: _attemptCount,
      stage: _persistedStageBreadcrumb!,
    );
    _logLine(
      'migration-attempt: $_attemptCount '
      '(${HiveToSqliteMigrationStage.migrating.name}/start)',
    );
  }

  /// Records an attempt that failed before [migrate] could run (i.e. during
  /// backup creation). [migrate] increments the counter itself via
  /// [_beginAttempt], so callers must only invoke this for backup-phase
  /// failures; otherwise a disk-full or unwritable-target user could never
  /// reach the skip escape hatch and would be trapped on the migration page.
  Future<void> recordFailedAttempt() async {
    final state = await _readAttemptState();
    _attemptCount = state.attempts + 1;
    _persistedStageBreadcrumb =
        '${HiveToSqliteMigrationStage.backingUp.name}/failed';
    await _writeAttemptState(
      attempts: _attemptCount,
      stage: _persistedStageBreadcrumb!,
    );
    _logLine(
      'migration-attempt: $_attemptCount '
      '(${HiveToSqliteMigrationStage.backingUp.name}/failed)',
    );
  }

  Future<void> _recordStageBreadcrumb(
    HiveToSqliteMigrationStage stage,
    String detail,
  ) async {
    final breadcrumb = '${stage.name}/$detail';
    if (breadcrumb == _persistedStageBreadcrumb) return;
    _persistedStageBreadcrumb = breadcrumb;
    _logLine('migration-stage: $breadcrumb');
    await _writeAttemptState(attempts: _attemptCount, stage: breadcrumb);
  }

  Future<void> _clearAttemptState() async {
    _attemptCount = 0;
    _persistedStageBreadcrumb = null;
    final file = _attemptStateFile;
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      await file.delete();
    }
  }

  Future<({int attempts, String? stage})> _readAttemptState() async {
    final file = _attemptStateFile;
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return (attempts: 0, stage: null);
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return (attempts: 0, stage: null);
      final attempts = decoded['attempts'];
      final stage = decoded['stage'];
      return (
        attempts: attempts is int && attempts > 0 ? attempts : 0,
        stage: stage is String && stage.isNotEmpty ? stage : null,
      );
    } catch (_) {
      return (attempts: 0, stage: null);
    }
  }

  Future<void> _writeAttemptState({
    required int attempts,
    required String stage,
  }) async {
    final file = _attemptStateFile;
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'attempts': attempts, 'stage': stage}),
      flush: true,
    );
    // POSIX rename replaces an existing target atomically. Windows requires
    // the target to be absent, which briefly opens a neither-file window.
    if (Platform.isWindows && await file.exists()) {
      await file.delete();
    }
    await temporary.rename(file.path);
  }

  void _registerHiveAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationAdapter());
    }
  }

  void _emit(
    HiveToSqliteMigrationStage stage,
    double progress,
    String title,
    String detail, {
    String? backupPath,
    String? error,
    int conversations = 0,
    int messages = 0,
    List<HiveToSqliteBackupItem>? backupItems,
  }) {
    final bounded = progress.clamp(0, 1).toDouble();
    _logLine('$title: $detail ${(bounded * 100).toStringAsFixed(0)}%');
    _controller.add(
      HiveToSqliteMigrationStatus(
        stage: stage,
        progress: bounded,
        title: title,
        detail: detail,
        backupPath: backupPath,
        error: error,
        log: List.of(_log),
        conversations: conversations,
        messages: messages,
        converted: _converted,
        malformed: _malformed,
        missingFiles: _missingFiles,
        backupItems: backupItems ?? _lastBackupItems,
        chatsExportDegraded: _chatsExportDegraded,
      ),
    );
  }

  void _logLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    _log.add(trimmed);
    if (_log.length > 200) {
      _log.removeRange(0, _log.length - 200);
    }
  }
}

List<MessagePart> _normalizeAttachmentPartUris(List<MessagePart> parts) {
  var changed = false;
  final out = <MessagePart>[];
  for (final part in parts) {
    if (part is ImagePart) {
      final uri = SandboxPathResolver.canonicalize(part.uri);
      if (uri != part.uri) {
        changed = true;
        out.add(
          ImagePart(
            uri: uri,
            mime: part.mime,
            assetId: part.assetId,
            unavailable: part.unavailable,
          ),
        );
      } else {
        out.add(part);
      }
    } else if (part is FilePart) {
      final uri = SandboxPathResolver.canonicalize(part.uri);
      if (uri != part.uri) {
        changed = true;
        out.add(
          FilePart(
            uri: uri,
            name: part.name,
            mime: part.mime,
            assetId: part.assetId,
            unavailable: part.unavailable,
          ),
        );
      } else {
        out.add(part);
      }
    } else {
      out.add(part);
    }
  }
  return changed ? out : parts;
}

class _MigrationRepairStats {
  int danglingMessageRefs = 0;
  int duplicateMessageIds = 0;
  int conversationIdMismatches = 0;
  int versionConflicts = 0;
  int decodeFailures = 0;
  int dirtyNumericFields = 0;
  int undecodableConversations = 0;

  bool get hasIssues =>
      danglingMessageRefs > 0 ||
      duplicateMessageIds > 0 ||
      conversationIdMismatches > 0 ||
      versionConflicts > 0 ||
      decodeFailures > 0 ||
      dirtyNumericFields > 0 ||
      undecodableConversations > 0;

  String describe() {
    return 'dangling=$danglingMessageRefs duplicates=$duplicateMessageIds '
        'conversationIdMismatches=$conversationIdMismatches '
        'versionConflicts=$versionConflicts '
        'decodeFailures=$decodeFailures '
        'dirtyNumericFields=$dirtyNumericFields '
        'undecodableConversations=$undecodableConversations';
  }
}

class _MigrationBackupManifest {
  const _MigrationBackupManifest({
    required this.entries,
    required this.items,
    required this.totalBytes,
  });

  final List<_MigrationBackupFileEntry> entries;
  final List<HiveToSqliteBackupItem> items;
  final int totalBytes;
}

class _MigrationBackupFile {
  const _MigrationBackupFile({
    required this.file,
    required this.entryName,
    required this.itemName,
    required this.bytes,
  });

  final File file;
  final String entryName;
  final String itemName;
  final int bytes;
}

class _MigrationBackupFileEntry {
  const _MigrationBackupFileEntry({
    required this.file,
    required this.entryName,
    required this.itemName,
    required this.bytes,
    required this.itemBytes,
    required this.itemStartBytes,
  });

  final File file;
  final String entryName;
  final String itemName;
  final int bytes;
  final int itemBytes;
  final int itemStartBytes;
}

class _MigrationZipWriter {
  _MigrationZipWriter(this._output, {int? zip64Threshold})
    : _zip64Threshold = zip64Threshold ?? _defaultZip64Threshold;

  static const int _localFileHeaderSignature = 0x04034b50;
  static const int _centralDirectoryHeaderSignature = 0x02014b50;
  static const int _endOfCentralDirectorySignature = 0x06054b50;
  static const int _zip64EndOfCentralDirectorySignature = 0x06064b50;
  static const int _zip64EndOfCentralDirectoryLocatorSignature = 0x07064b50;
  static const int _dataDescriptorSignature = 0x08074b50;
  static const int _versionNeeded = 45;
  static const int _utf8Flag = 1 << 11;
  static const int _dataDescriptorFlag = 1 << 3;
  static const int _deflateMethod = 8;
  static const int _maxZip32 = 0xffffffff;
  static const int _defaultZip64Threshold = _maxZip32 - (16 * 1024 * 1024);
  static const int _chunkSize = 1024 * 1024;

  final _MigrationZipOutput _output;
  final int _zip64Threshold;
  final List<_MigrationZipEntry> _entries = <_MigrationZipEntry>[];
  bool _closed = false;

  Future<int> addFile(
    File file,
    String entryName, {
    required void Function(int writtenBytes) onProgress,
  }) async {
    if (_closed) {
      throw StateError('Cannot add files after the ZIP writer is closed.');
    }
    if (entryName.isEmpty) return 0;

    final stat = await file.stat();
    final uncompressedSize = stat.size;
    final usesZip64Entry = uncompressedSize > _zip64Threshold;

    final modified = stat.modified;
    final modTime = _zipTime(modified);
    final modDate = _zipDate(modified);
    final nameBytes = utf8.encode(entryName.replaceAll('\\', '/'));
    if (nameBytes.length > 0xffff) {
      throw FileSystemException('ZIP entry name exceeds ZIP32 limit');
    }
    final localHeaderOffset = _output.length;

    _writeLocalHeader(
      nameBytes: nameBytes,
      modTime: modTime,
      modDate: modDate,
      usesZip64: usesZip64Entry,
    );

    final written = await _writeDeflatedFile(file, onProgress: onProgress);
    _writeDataDescriptor(written, usesZip64: usesZip64Entry);
    if (_output.shouldFlush) await _output.flush();

    _entries.add(
      _MigrationZipEntry(
        nameBytes: nameBytes,
        modTime: modTime,
        modDate: modDate,
        crc32: written.crc32,
        compressedSize: written.compressedSize,
        uncompressedSize: written.uncompressedSize,
        localHeaderOffset: localHeaderOffset,
        mode: stat.mode,
        usesZip64: usesZip64Entry,
      ),
    );
    return written.uncompressedSize;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    try {
      final centralDirectoryOffset = _output.length;
      for (final entry in _entries) {
        _writeCentralDirectoryHeader(entry);
        if (_output.shouldFlush) await _output.flush();
      }
      final centralDirectorySize = _output.length - centralDirectoryOffset;

      _writeEndOfCentralDirectory(
        centralDirectoryOffset: centralDirectoryOffset,
        centralDirectorySize: centralDirectorySize,
      );
      await _output.close();
    } catch (_) {
      await _output.close(discardPending: true);
      rethrow;
    }
  }

  Future<void> closeIfNeeded() async {
    if (!_closed) {
      _closed = true;
      await _output.close(discardPending: true);
    }
  }

  void _writeLocalHeader({
    required List<int> nameBytes,
    required int modTime,
    required int modDate,
    required bool usesZip64,
  }) {
    _output.writeUint32(_localFileHeaderSignature);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_utf8Flag | _dataDescriptorFlag);
    _output.writeUint16(_deflateMethod);
    _output.writeUint16(modTime);
    _output.writeUint16(modDate);
    _output.writeUint32(0);
    _output.writeUint32(usesZip64 ? _maxZip32 : 0);
    _output.writeUint32(usesZip64 ? _maxZip32 : 0);
    _output.writeUint16(nameBytes.length);
    _output.writeUint16(usesZip64 ? 20 : 0);
    _output.writeBytes(nameBytes);
    if (usesZip64) {
      _output.writeUint16(0x0001);
      _output.writeUint16(16);
      _output.writeUint64(0);
      _output.writeUint64(0);
    }
  }

  Future<_MigrationZipWrittenFile> _writeDeflatedFile(
    File file, {
    required void Function(int writtenBytes) onProgress,
  }) async {
    var crc32 = 0;
    var compressedSize = 0;
    var uncompressedSize = 0;

    Stream<List<int>> sourceChunks() async* {
      final raf = await file.open();
      try {
        while (true) {
          final chunk = await raf.read(_chunkSize);
          if (chunk.isEmpty) break;
          crc32 = getCrc32(chunk, crc32);
          uncompressedSize += chunk.length;
          onProgress(uncompressedSize);
          yield chunk;
        }
      } finally {
        await raf.close();
      }
    }

    final compressed = sourceChunks().transform(
      ZLibCodec(level: 1, raw: true).encoder,
    );
    await for (final chunk in compressed) {
      if (chunk.isNotEmpty) {
        compressedSize += chunk.length;
        _output.writeBytes(chunk);
        if (_output.shouldFlush) await _output.flush();
      }
    }

    return _MigrationZipWrittenFile(
      crc32: crc32,
      compressedSize: compressedSize,
      uncompressedSize: uncompressedSize,
    );
  }

  void _writeDataDescriptor(
    _MigrationZipWrittenFile written, {
    required bool usesZip64,
  }) {
    _output.writeUint32(_dataDescriptorSignature);
    _output.writeUint32(written.crc32);
    if (usesZip64) {
      _output.writeUint64(written.compressedSize);
      _output.writeUint64(written.uncompressedSize);
    } else {
      _output.writeUint32(written.compressedSize);
      _output.writeUint32(written.uncompressedSize);
    }
  }

  void _writeCentralDirectoryHeader(_MigrationZipEntry entry) {
    final usesZip64 =
        entry.usesZip64 ||
        entry.compressedSize > _maxZip32 ||
        entry.uncompressedSize > _maxZip32 ||
        entry.localHeaderOffset > _maxZip32;
    _output.writeUint32(_centralDirectoryHeaderSignature);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_utf8Flag | _dataDescriptorFlag);
    _output.writeUint16(_deflateMethod);
    _output.writeUint16(entry.modTime);
    _output.writeUint16(entry.modDate);
    _output.writeUint32(entry.crc32);
    _output.writeUint32(usesZip64 ? _maxZip32 : entry.compressedSize);
    _output.writeUint32(usesZip64 ? _maxZip32 : entry.uncompressedSize);
    _output.writeUint16(entry.nameBytes.length);
    _output.writeUint16(usesZip64 ? 28 : 0);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint32(entry.mode << 16);
    _output.writeUint32(usesZip64 ? _maxZip32 : entry.localHeaderOffset);
    _output.writeBytes(entry.nameBytes);
    if (usesZip64) {
      _output.writeUint16(0x0001);
      _output.writeUint16(24);
      _output.writeUint64(entry.uncompressedSize);
      _output.writeUint64(entry.compressedSize);
      _output.writeUint64(entry.localHeaderOffset);
    }
  }

  void _writeEndOfCentralDirectory({
    required int centralDirectoryOffset,
    required int centralDirectorySize,
  }) {
    final zip64EocdOffset = _output.length;
    _output.writeUint32(_zip64EndOfCentralDirectorySignature);
    _output.writeUint64(44);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_versionNeeded);
    _output.writeUint32(0);
    _output.writeUint32(0);
    _output.writeUint64(_entries.length);
    _output.writeUint64(_entries.length);
    _output.writeUint64(centralDirectorySize);
    _output.writeUint64(centralDirectoryOffset);

    _output.writeUint32(_zip64EndOfCentralDirectoryLocatorSignature);
    _output.writeUint32(0);
    _output.writeUint64(zip64EocdOffset);
    _output.writeUint32(1);

    _output.writeUint32(_endOfCentralDirectorySignature);
    _output.writeUint16(0);
    _output.writeUint16(0xffff);
    _output.writeUint16(0xffff);
    _output.writeUint16(0xffff);
    _output.writeUint32(_maxZip32);
    _output.writeUint32(_maxZip32);
    _output.writeUint16(0);
  }

  static int _zipTime(DateTime value) {
    return ((value.hour & 0x1f) << 11) |
        ((value.minute & 0x3f) << 5) |
        ((value.second ~/ 2) & 0x1f);
  }

  static int _zipDate(DateTime value) {
    final year = value.year < 1980 ? 1980 : value.year;
    return (((year - 1980) & 0x7f) << 9) |
        ((value.month & 0x0f) << 5) |
        (value.day & 0x1f);
  }
}

/// Buffered sequential ZIP output. The sink is awaited every 1 MiB to preserve
/// backpressure for multi-gigabyte backups.
class _MigrationZipOutput {
  _MigrationZipOutput.toSink(this._writeChunk) : _closeSink = null;

  _MigrationZipOutput._(this._writeChunk, this._closeSink);

  static Future<_MigrationZipOutput> openFile(String path) async {
    final file = await File(path).open(mode: FileMode.write);
    return _MigrationZipOutput._(
      (bytes) async {
        await file.writeFrom(bytes);
      },
      () async {
        await file.close();
      },
    );
  }

  static const _flushThreshold = 1024 * 1024;

  final MigrationBackupChunkWriter _writeChunk;
  final Future<void> Function()? _closeSink;
  // Compression converters may reuse their output buffers. Copy into the
  // bounded staging buffer so bytes cannot change before the async sink runs.
  final BytesBuilder _pending = BytesBuilder(copy: true);
  var length = 0;
  var _closed = false;

  bool get shouldFlush => _pending.length >= _flushThreshold;

  void writeByte(int value) {
    _pending.addByte(value);
    length++;
  }

  void writeBytes(List<int> bytes) {
    if (bytes.isEmpty) return;
    _pending.add(bytes);
    length += bytes.length;
  }

  void writeUint16(int value) {
    writeByte(value & 0xff);
    writeByte((value >> 8) & 0xff);
  }

  void writeUint32(int value) {
    writeByte(value & 0xff);
    writeByte((value >> 8) & 0xff);
    writeByte((value >> 16) & 0xff);
    writeByte((value >> 24) & 0xff);
  }

  void writeUint64(int value) {
    writeUint32(value & 0xffffffff);
    writeUint32((value >> 32) & 0xffffffff);
  }

  Future<void> flush() async {
    if (_pending.isEmpty) return;
    await _writeChunk(_pending.takeBytes());
  }

  Future<void> close({bool discardPending = false}) async {
    if (_closed) return;
    _closed = true;
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      if (discardPending) {
        _pending.clear();
      } else {
        await flush();
      }
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      await _closeSink?.call();
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}

class _MigrationZipEntry {
  const _MigrationZipEntry({
    required this.nameBytes,
    required this.modTime,
    required this.modDate,
    required this.crc32,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
    required this.mode,
    required this.usesZip64,
  });

  final List<int> nameBytes;
  final int modTime;
  final int modDate;
  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
  final int mode;
  final bool usesZip64;
}

class _MigrationZipWrittenFile {
  const _MigrationZipWrittenFile({
    required this.crc32,
    required this.compressedSize,
    required this.uncompressedSize,
  });

  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
}
