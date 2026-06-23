import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/database/chat_database_repository.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/conversation.dart';
import '../../core/services/backup/data_sync.dart' as backup_sync;
import '../../utils/app_directories.dart';

enum HiveToSqliteMigrationStage {
  intro,
  backupReady,
  backingUp,
  migrating,
  complete,
  failed,
}

enum HiveToSqliteBackupItemState { pending, active, done }

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
    this.backupItems = const <HiveToSqliteBackupItem>[],
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
  final List<HiveToSqliteBackupItem> backupItems;

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
    List<HiveToSqliteBackupItem>? backupItems,
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
      backupItems: backupItems ?? this.backupItems,
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
  HiveToSqliteMigrationService(this.decision);

  static const _conversationBoxName = 'conversations';
  static const _messagesBoxName = 'messages';
  static const _toolEventsBoxName = 'tool_events_v1';
  static const _activeStreamingKey = '_active_streaming_ids';
  static const _messageBatchSize = 128;
  static const _settingsBackupName = 'settings.json';
  static const _chatsBackupName = 'chats.json';
  static const _backupPreparationShare = 0.15;
  static const _backupFileShare = 1 - _backupPreparationShare;
  static const _backupDirectories =
      <({String directoryName, String zipPrefix})>[
        (directoryName: 'upload', zipPrefix: 'upload'),
        (directoryName: 'images', zipPrefix: 'images'),
        (directoryName: 'avatars', zipPrefix: 'avatars'),
        (directoryName: 'fonts', zipPrefix: 'fonts'),
      ];

  final HiveToSqliteMigrationDecision decision;
  final _controller = StreamController<HiveToSqliteMigrationStatus>.broadcast();
  final _log = <String>[];
  var _lastBackupItems = const <HiveToSqliteBackupItem>[];

  Stream<HiveToSqliteMigrationStatus> get statusStream => _controller.stream;

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
    if (sqliteFile.existsSync()) {
      final repo = ChatDatabaseRepository.open(file: sqliteFile);
      try {
        if (await repo.isMigrationComplete()) {
          return HiveToSqliteMigrationDecision(
            needsMigration: false,
            appDataDir: appDataDir,
            sqliteFile: sqliteFile,
            hiveFiles: hiveFiles,
          );
        }
      } finally {
        await repo.close();
      }
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

  Future<File> backupTo(Directory selectedDirectory) async {
    await selectedDirectory.create(recursive: true);
    final backupFile = File(p.join(selectedDirectory.path, _backupFileName()));
    return _backupToFile(backupFile);
  }

  Future<File> backupToTemporaryFile() async {
    return _backupToFile(
      File(p.join(Directory.systemTemp.path, _backupFileName())),
    );
  }

  Future<File> _backupToFile(File backupFile) async {
    Directory? workDir;
    final plannedItems = _updateBackupItem(
      _backupItemsForDecision(),
      _settingsBackupName,
      state: HiveToSqliteBackupItemState.active,
    );
    _lastBackupItems = plannedItems;
    var copiedBytes = 0;
    var totalBytes = 0;
    _emit(
      HiveToSqliteMigrationStage.backingUp,
      0,
      'backup',
      _settingsBackupName,
      backupPath: backupFile.path,
      backupItems: plannedItems,
    );

    _MigrationZipWriter? writer;
    try {
      workDir = await Directory.systemTemp.createTemp(
        'kelivo_migration_backup_',
      );
      final manifest = await _buildBackupManifest(
        workDir,
        backupFile.path,
        plannedItems,
      );
      _lastBackupItems = manifest.items;
      totalBytes = manifest.totalBytes;

      await backupFile.parent.create(recursive: true);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      writer = _MigrationZipWriter(backupFile.path);
      for (final entry in manifest.entries) {
        final name = entry.itemName;
        _lastBackupItems = _updateBackupItem(
          _lastBackupItems,
          name,
          bytes: entry.itemBytes,
          state: HiveToSqliteBackupItemState.active,
        );
        _emit(
          HiveToSqliteMigrationStage.backingUp,
          _backupProgress(copiedBytes, totalBytes),
          'backup',
          entry.entryName,
          backupPath: backupFile.path,
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
            _emit(
              HiveToSqliteMigrationStage.backingUp,
              _backupProgress(currentTotal, totalBytes),
              'backup',
              entry.entryName,
              backupPath: backupFile.path,
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
      writer.closeSync();
    } catch (error, stackTrace) {
      _logLine('$error');
      _logLine(stackTrace.toString());
      writer?.closeIfNeededSync();
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      _controller.add(
        HiveToSqliteMigrationStatus(
          stage: HiveToSqliteMigrationStage.failed,
          progress: totalBytes == 0
              ? 0
              : _backupProgress(copiedBytes, totalBytes).clamp(0, 1).toDouble(),
          title: 'failed',
          detail: 'backup',
          error: '$error',
          log: List.of(_log),
          backupItems: _lastBackupItems,
        ),
      );
      rethrow;
    } finally {
      writer?.closeIfNeededSync();
      await _deleteDirectoryQuietly(workDir);
    }

    _emit(
      HiveToSqliteMigrationStage.backupReady,
      1,
      'backup',
      'done',
      backupPath: backupFile.path,
      backupItems: _lastBackupItems,
    );
    return backupFile;
  }

  String _backupFileName() {
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return 'kelivo_migration_backup_$timestamp.zip';
  }

  Future<void> migrate({required File backupFile}) async {
    ChatDatabaseRepository? repo;
    LazyBox<Conversation>? conversationsBox;
    LazyBox<ChatMessage>? messagesBox;
    LazyBox<dynamic>? toolEventsBox;
    try {
      _registerHiveAdapters();
      await Hive.initFlutter(decision.appDataDir.path);
      conversationsBox = await Hive.openLazyBox<Conversation>(
        _conversationBoxName,
      );
      messagesBox = await Hive.openLazyBox<ChatMessage>(_messagesBoxName);
      toolEventsBox = await Hive.openLazyBox<dynamic>(_toolEventsBoxName);

      final tempFile = File('${decision.sqliteFile.path}.migrating');
      await _deleteSqliteFamily(tempFile);
      repo = ChatDatabaseRepository.open(file: tempFile);

      final conversations = <Conversation>[];
      for (final key in conversationsBox.keys) {
        final conversation = await conversationsBox.get(key);
        if (conversation != null) conversations.add(conversation);
      }
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final totalMessages = conversations.fold<int>(
        0,
        (sum, conversation) => sum + conversation.messageIds.length,
      );
      var migratedMessages = 0;
      _emit(
        HiveToSqliteMigrationStage.migrating,
        0.04,
        'migrate',
        'schema',
        backupPath: backupFile.path,
        backupItems: _lastBackupItems,
        conversations: conversations.length,
        messages: totalMessages,
      );

      await repo.clearAllData();
      for (final conversation in conversations) {
        await repo.putConversation(conversation);
        var order = 0;
        for (
          var start = 0;
          start < conversation.messageIds.length;
          start += _messageBatchSize
        ) {
          final end = (start + _messageBatchSize)
              .clamp(start, conversation.messageIds.length)
              .toInt();
          final batch = <ChatMessage>[];
          for (var i = start; i < end; i++) {
            final message = await messagesBox.get(conversation.messageIds[i]);
            if (message == null) continue;
            batch.add(message);
          }
          for (final message in batch) {
            await repo.putMessage(message, messageOrder: order);
            order++;
            final events = await _toolEventsFor(toolEventsBox, message.id);
            if (events.isNotEmpty) {
              await repo.setToolEvents(message.id, events);
            }
            final signature = await _signatureFor(toolEventsBox, message.id);
            if (signature != null) {
              await repo.setGeminiThoughtSignature(message.id, signature);
            }
          }
          migratedMessages += batch.length;
          final messageProgress = totalMessages == 0
              ? 0.9
              : 0.04 + (migratedMessages / totalMessages) * 0.86;
          _emit(
            HiveToSqliteMigrationStage.migrating,
            messageProgress,
            'migrate',
            'messages',
            backupPath: backupFile.path,
            backupItems: _lastBackupItems,
            conversations: conversations.length,
            messages: migratedMessages,
          );
          await Future<void>.delayed(Duration.zero);
        }
      }

      _emit(
        HiveToSqliteMigrationStage.migrating,
        0.94,
        'migrate',
        'tool_events',
        backupPath: backupFile.path,
        backupItems: _lastBackupItems,
        conversations: conversations.length,
        messages: migratedMessages,
      );
      final active = await toolEventsBox.get(_activeStreamingKey);
      if (active is List && active.isNotEmpty) {
        await repo.setActiveStreamingIds(active.map((e) => '$e').toList());
      }
      _emit(
        HiveToSqliteMigrationStage.migrating,
        0.98,
        'migrate',
        'validate',
        backupPath: backupFile.path,
        backupItems: _lastBackupItems,
        conversations: conversations.length,
        messages: migratedMessages,
      );
      await _validate(repo, conversations.length, totalMessages);
      await repo.markMigrationComplete();
      await repo.checkpoint();
      await repo.close();
      repo = null;

      await _replaceSqlite(tempFile, decision.sqliteFile);
      _emit(
        HiveToSqliteMigrationStage.complete,
        1,
        'complete',
        'done',
        backupPath: backupFile.path,
        backupItems: _lastBackupItems,
        conversations: conversations.length,
        messages: totalMessages,
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
          backupPath: backupFile.path,
          error: '$error',
          log: List.of(_log),
          backupItems: _lastBackupItems,
        ),
      );
      rethrow;
    } finally {
      await repo?.close();
      await conversationsBox?.close();
      await messagesBox?.close();
      await toolEventsBox?.close();
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  List<HiveToSqliteBackupItem> _backupItemsForDecision() {
    return [
      const HiveToSqliteBackupItem(name: _settingsBackupName, bytes: 0),
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
    String backupPath,
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

    items = _updateBackupItem(
      items,
      _chatsBackupName,
      state: HiveToSqliteBackupItemState.active,
    );
    _lastBackupItems = items;
    _emit(
      HiveToSqliteMigrationStage.backingUp,
      0.03,
      'backup',
      _chatsBackupName,
      backupPath: backupPath,
      backupItems: items,
    );
    final chatsFile = await _exportLegacyChatsToFile(
      workDir,
      onProgress: (progress) {
        _lastBackupItems = _updateBackupItem(
          _lastBackupItems.isEmpty ? items : _lastBackupItems,
          _chatsBackupName,
          state: HiveToSqliteBackupItemState.active,
        );
        _emit(
          HiveToSqliteMigrationStage.backingUp,
          0.03 + progress.clamp(0, 1) * 0.1,
          'backup',
          _chatsBackupName,
          backupPath: backupPath,
          backupItems: _lastBackupItems,
        );
      },
    );
    final chatsBytes = await chatsFile.length();
    items = _updateBackupItem(
      _lastBackupItems.isEmpty ? items : _lastBackupItems,
      _chatsBackupName,
      bytes: chatsBytes,
      writtenBytes: chatsBytes,
      state: HiveToSqliteBackupItemState.done,
    );
    _lastBackupItems = items;
    files.add(
      _MigrationBackupFile(
        file: chatsFile,
        entryName: _chatsBackupName,
        itemName: _chatsBackupName,
        bytes: chatsBytes,
      ),
    );

    for (final hiveFile in decision.hiveFiles) {
      final itemName = p.basename(hiveFile.path);
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
    final prefs = await backup_sync.SharedPreferencesAsync.instance;
    final map = await prefs.snapshot();
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
                sink.write(jsonEncode(message.toJson()));
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

  double _backupProgress(int copiedBytes, int totalBytes) {
    if (totalBytes <= 0) return 1;
    return _backupPreparationShare +
        (copiedBytes / totalBytes) * _backupFileShare;
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
    ChatDatabaseRepository repo,
    int expectedConversations,
    int expectedMessages,
  ) async {
    final conversationCount = repo.getConversationCountSync();
    final messageCount = repo.getTotalMessageCountSync();
    if (conversationCount != expectedConversations ||
        messageCount != expectedMessages) {
      throw StateError(
        'Migration validation failed: expected $expectedConversations conversations / $expectedMessages messages, got $conversationCount / $messageCount.',
      );
    }
  }

  Future<void> _replaceSqlite(File tempFile, File sqliteFile) async {
    await _deleteSqliteFamily(sqliteFile);
    for (final suffix in ['', '-wal', '-shm']) {
      final source = File('${tempFile.path}$suffix');
      if (await source.exists()) {
        await source.rename('${sqliteFile.path}$suffix');
      }
    }
  }

  Future<void> _deleteSqliteFamily(File file) async {
    for (final suffix in ['', '-wal', '-shm']) {
      final target = File('${file.path}$suffix');
      if (await target.exists()) {
        await target.delete();
      }
    }
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
        backupItems: backupItems ?? _lastBackupItems,
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
  _MigrationZipWriter(String outPath) : _output = OutputFileStream(outPath);

  static const int _localFileHeaderSignature = 0x04034b50;
  static const int _centralDirectoryHeaderSignature = 0x02014b50;
  static const int _endOfCentralDirectorySignature = 0x06054b50;
  static const int _dataDescriptorSignature = 0x08074b50;
  static const int _versionNeeded = 20;
  static const int _utf8Flag = 1 << 11;
  static const int _dataDescriptorFlag = 1 << 3;
  static const int _deflateMethod = 8;
  static const int _maxZip32 = 0xffffffff;
  static const int _maxZipEntries = 0xffff;
  static const int _chunkSize = 1024 * 1024;

  final OutputFileStream _output;
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
    _checkZip32(uncompressedSize, 'file size');
    _checkZip32(_output.length, 'local header offset');

    final modified = stat.modified;
    final modTime = _zipTime(modified);
    final modDate = _zipDate(modified);
    final nameBytes = utf8.encode(entryName.replaceAll('\\', '/'));
    final localHeaderOffset = _output.length;

    _writeLocalHeader(nameBytes: nameBytes, modTime: modTime, modDate: modDate);

    final written = await _writeDeflatedFile(file, onProgress: onProgress);
    _checkZip32(written.compressedSize, 'compressed size');
    _checkZip32(written.uncompressedSize, 'uncompressed size');

    _writeDataDescriptor(written);

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
      ),
    );
    return written.uncompressedSize;
  }

  void closeSync() {
    if (_closed) return;
    _checkEntryCount();

    final centralDirectoryOffset = _output.length;
    _checkZip32(centralDirectoryOffset, 'central directory offset');
    for (final entry in _entries) {
      _writeCentralDirectoryHeader(entry);
    }
    final centralDirectorySize = _output.length - centralDirectoryOffset;
    _checkZip32(centralDirectorySize, 'central directory size');

    _writeEndOfCentralDirectory(
      centralDirectoryOffset: centralDirectoryOffset,
      centralDirectorySize: centralDirectorySize,
    );
    _output.closeSync();
    _closed = true;
  }

  void closeIfNeededSync() {
    if (!_closed) {
      _output.closeSync();
      _closed = true;
    }
  }

  void _writeLocalHeader({
    required List<int> nameBytes,
    required int modTime,
    required int modDate,
  }) {
    _output.writeUint32(_localFileHeaderSignature);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_utf8Flag | _dataDescriptorFlag);
    _output.writeUint16(_deflateMethod);
    _output.writeUint16(modTime);
    _output.writeUint16(modDate);
    _output.writeUint32(0);
    _output.writeUint32(0);
    _output.writeUint32(0);
    _output.writeUint16(nameBytes.length);
    _output.writeUint16(0);
    _output.writeBytes(nameBytes);
  }

  Future<_MigrationZipWrittenFile> _writeDeflatedFile(
    File file, {
    required void Function(int writtenBytes) onProgress,
  }) async {
    final compressedSink = _CountingOutputSink(_output);
    final inputSink = ZLibCodec(
      level: 1,
      raw: true,
    ).encoder.startChunkedConversion(compressedSink);

    final raf = await file.open();
    final buffer = Uint8List(_chunkSize);
    var crc32 = 0;
    var uncompressedSize = 0;
    try {
      while (true) {
        final read = await raf.readInto(buffer);
        if (read == 0) break;
        final chunk = Uint8List.sublistView(buffer, 0, read);
        crc32 = getCrc32(chunk, crc32);
        uncompressedSize += read;
        inputSink.add(chunk);
        onProgress(uncompressedSize);
        await Future<void>.delayed(Duration.zero);
      }
      inputSink.close();
    } finally {
      await raf.close();
    }

    return _MigrationZipWrittenFile(
      crc32: crc32,
      compressedSize: compressedSink.bytesWritten,
      uncompressedSize: uncompressedSize,
    );
  }

  void _writeDataDescriptor(_MigrationZipWrittenFile written) {
    _output.writeUint32(_dataDescriptorSignature);
    _output.writeUint32(written.crc32);
    _output.writeUint32(written.compressedSize);
    _output.writeUint32(written.uncompressedSize);
  }

  void _writeCentralDirectoryHeader(_MigrationZipEntry entry) {
    _output.writeUint32(_centralDirectoryHeaderSignature);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_versionNeeded);
    _output.writeUint16(_utf8Flag | _dataDescriptorFlag);
    _output.writeUint16(_deflateMethod);
    _output.writeUint16(entry.modTime);
    _output.writeUint16(entry.modDate);
    _output.writeUint32(entry.crc32);
    _output.writeUint32(entry.compressedSize);
    _output.writeUint32(entry.uncompressedSize);
    _output.writeUint16(entry.nameBytes.length);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint32(entry.mode << 16);
    _output.writeUint32(entry.localHeaderOffset);
    _output.writeBytes(entry.nameBytes);
  }

  void _writeEndOfCentralDirectory({
    required int centralDirectoryOffset,
    required int centralDirectorySize,
  }) {
    _output.writeUint32(_endOfCentralDirectorySignature);
    _output.writeUint16(0);
    _output.writeUint16(0);
    _output.writeUint16(_entries.length);
    _output.writeUint16(_entries.length);
    _output.writeUint32(centralDirectorySize);
    _output.writeUint32(centralDirectoryOffset);
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

  static void _checkZip32(int value, String field) {
    if (value > _maxZip32) {
      throw FileSystemException('ZIP entry exceeds ZIP32 limit: $field');
    }
  }

  void _checkEntryCount() {
    if (_entries.length > _maxZipEntries) {
      throw FileSystemException('ZIP entry count exceeds ZIP32 limit');
    }
  }
}

class _CountingOutputSink implements Sink<List<int>> {
  _CountingOutputSink(this._output);

  final OutputFileStream _output;
  int bytesWritten = 0;

  @override
  void add(List<int> data) {
    if (data.isEmpty) return;
    _output.writeBytes(data);
    bytesWritten += data.length;
  }

  @override
  void close() {}
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
  });

  final List<int> nameBytes;
  final int modTime;
  final int modDate;
  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
  final int mode;
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
