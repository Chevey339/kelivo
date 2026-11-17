import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../database/business_preferences.dart';
import '../database/business_repository.dart';
import '../models/backup.dart';
import '../services/chat/chat_service.dart';
import '../services/backup/backup_cancel_token.dart';
import '../services/backup/backup_encryption.dart';
import '../services/backup/backup_task_progress.dart';
import '../services/backup/data_sync.dart';

class BackupProvider extends ChangeNotifier {
  final DataSync _dataSync;
  bool _busy = false;
  String? _message;

  BackupProvider({
    required ChatService chatService,
    required BusinessRepository businessRepository,
    required BusinessPreferences businessPreferences,
  }) : _dataSync = DataSync(
         chatService: chatService,
         businessRepository: businessRepository,
         businessPreferences: businessPreferences,
       );

  bool get busy => _busy;
  String? get message => _message;
  int get skippedConversations =>
      _dataSync.lastMergeReport?.skippedConversations ?? 0;

  Future<void> cleanPartials(WebDavConfig cfg) =>
      _dataSync.cleanWebDavPartials(cfg);

  Future<void> test(WebDavConfig cfg) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _dataSync.testWebdav(cfg);
      _message = 'OK';
    } catch (e) {
      _message = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> backup(
    WebDavConfig cfg, {
    String? password,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _dataSync.backupToWebDav(
        cfg,
        password: password,
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
    WebDavConfig cfg,
    BackupFileItem item, {
    RestoreMode mode = RestoreMode.overwrite,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    bool allowUnverifiedForwardCompatible = false,
    ForwardCompatibilityPrompt? onForwardCompatibility,
    BackupPasswordPrompt? onPassword,
  }) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _dataSync.restoreFromWebDav(
        cfg,
        item,
        mode: mode,
        onProgress: onProgress,
        cancelToken: cancelToken,
        allowUnverifiedForwardCompatible: allowUnverifiedForwardCompatible,
        onForwardCompatibility: onForwardCompatibility,
        onPassword: onPassword,
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

  Future<List<BackupFileItem>> listRemote(
    WebDavConfig cfg, {
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    return _dataSync.listBackupFiles(
      cfg,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<List<BackupFileItem>> deleteAndReload(
    WebDavConfig cfg,
    BackupFileItem item,
  ) async {
    await _dataSync.deleteWebDavBackupFile(cfg, item);
    return _dataSync.listBackupFiles(cfg);
  }

  Future<File> exportToFile(
    WebDavConfig cfg, {
    String? password,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) => _dataSync.exportToFile(
    cfg,
    password: password,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );

  Future<void> restoreFromLocalFile(
    File file,
    WebDavConfig cfg, {
    RestoreMode mode = RestoreMode.overwrite,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    bool allowUnverifiedForwardCompatible = false,
    ForwardCompatibilityPrompt? onForwardCompatibility,
    BackupPasswordPrompt? onPassword,
  }) => _dataSync.restoreFromLocalFile(
    file,
    cfg,
    mode: mode,
    onProgress: onProgress,
    cancelToken: cancelToken,
    allowUnverifiedForwardCompatible: allowUnverifiedForwardCompatible,
    onForwardCompatibility: onForwardCompatibility,
    onPassword: onPassword,
  );
}
