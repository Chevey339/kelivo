import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../database/business_preferences.dart';
import '../database/business_repository.dart';
import '../models/backup.dart';
import '../services/chat/chat_service.dart';
import '../services/backup/backup_cancel_token.dart';
import '../services/backup/backup_task_progress.dart';
import '../services/backup/data_sync.dart';
import '../services/backup/lan_sync_service.dart';

class BackupProvider extends ChangeNotifier {
  final DataSync _dataSync;
  WebDavConfig _cfg;
  bool _busy = false;
  String? _message;

  BackupProvider({
    required ChatService chatService,
    required BusinessRepository businessRepository,
    required BusinessPreferences businessPreferences,
    WebDavConfig? initialConfig,
  }) : _dataSync = DataSync(
         chatService: chatService,
         businessRepository: businessRepository,
         businessPreferences: businessPreferences,
       ),
       _cfg = initialConfig ?? const WebDavConfig();

  WebDavConfig get config => _cfg;
  bool get busy => _busy;
  String? get message => _message;
  int get skippedConversations =>
      _dataSync.lastMergeReport?.skippedConversations ?? 0;

  void updateConfig(WebDavConfig cfg) {
    _cfg = cfg;
    notifyListeners();
  }

  Future<void> test() async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _dataSync.testWebdav(_cfg);
      _message = 'OK';
    } catch (e) {
      _message = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> backup({
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _dataSync.backupToWebDav(
        _cfg,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      _message = 'Backup uploaded';
      return true;
    } catch (e) {
      if (e is BackupCancelledException) rethrow;
      _message = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> restoreFromItem(
    BackupFileItem item, {
    RestoreMode mode = RestoreMode.overwrite,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    bool allowUnverifiedForwardCompatible = false,
    ForwardCompatibilityPrompt? onForwardCompatibility,
  }) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _dataSync.restoreFromWebDav(
        _cfg,
        item,
        mode: mode,
        onProgress: onProgress,
        cancelToken: cancelToken,
        allowUnverifiedForwardCompatible: allowUnverifiedForwardCompatible,
        onForwardCompatibility: onForwardCompatibility,
      );
      _message = 'Restored';
    } catch (e) {
      _message = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<List<BackupFileItem>> listRemote({
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    return _dataSync.listBackupFiles(
      _cfg,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<List<BackupFileItem>> deleteAndReload(BackupFileItem item) async {
    await _dataSync.deleteWebDavBackupFile(_cfg, item);
    return _dataSync.listBackupFiles(_cfg);
  }

  Future<File> exportToFile({
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) => _dataSync.exportToFile(
    _cfg,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );

  Future<void> restoreFromLocalFile(
    File file, {
    RestoreMode mode = RestoreMode.overwrite,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    bool allowUnverifiedForwardCompatible = false,
    ForwardCompatibilityPrompt? onForwardCompatibility,
  }) => _dataSync.restoreFromLocalFile(
    file,
    _cfg,
    mode: mode,
    onProgress: onProgress,
    cancelToken: cancelToken,
    allowUnverifiedForwardCompatible: allowUnverifiedForwardCompatible,
    onForwardCompatibility: onForwardCompatibility,
  );

  Future<LanSyncShareSession> startLanShare() async {
    _busy = true;
    _message = null;
    notifyListeners();
    File? archive;
    try {
      archive = await _dataSync.prepareBackupFile(_cfg);
      final session = await LanSyncShareSession.start(archive);
      archive = null; // The session now owns and cleans up this file.
      _message = 'LAN share ready';
      return session;
    } catch (error) {
      _message = error.toString();
      rethrow;
    } finally {
      await DataSync.cleanupTemporaryBackupFile(archive);
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> restoreFromLan(
    String link, {
    RestoreMode mode = RestoreMode.merge,
    void Function(int received, int? total)? onProgress,
  }) async {
    _busy = true;
    _message = null;
    notifyListeners();
    File? archive;
    try {
      archive = await LanSyncClient.download(link, onProgress: onProgress);
      await _dataSync.restoreFromLocalFile(archive, _cfg, mode: mode);
      _message = 'Restored';
    } catch (error) {
      _message = error.toString();
      rethrow;
    } finally {
      await DataSync.cleanupTemporaryBackupFile(archive);
      _busy = false;
      notifyListeners();
    }
  }
}
