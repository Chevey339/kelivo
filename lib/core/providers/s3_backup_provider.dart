import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../database/business_preferences.dart';
import '../database/business_repository.dart';
import '../models/backup.dart';
import '../services/backup/backup_cancel_token.dart';
import '../services/backup/backup_encryption.dart';
import '../services/backup/backup_task_progress.dart';
import '../services/backup/data_sync.dart';
import '../services/backup/s3_client.dart';
import '../services/backup/backup_staging.dart';
import '../services/backup/backup_partials.dart';
import '../services/chat/chat_service.dart';

class S3BackupProvider extends ChangeNotifier {
  final DataSync _dataSync;
  final S3BackupClient _client;

  bool _busy = false;
  String? _message;

  S3BackupProvider({
    required ChatService chatService,
    required BusinessRepository businessRepository,
    required BusinessPreferences businessPreferences,
  }) : _dataSync = DataSync(
         chatService: chatService,
         businessRepository: businessRepository,
         businessPreferences: businessPreferences,
       ),
       _client = S3BackupClient(partials: BackupPartials(businessPreferences));

  bool get busy => _busy;
  String? get message => _message;
  int get skippedConversations =>
      _dataSync.lastMergeReport?.skippedConversations ?? 0;

  static String _normalizePrefix(String prefix) {
    var s = prefix.trim().replaceAll(RegExp(r'^/+'), '');
    if (s.isEmpty) return '';
    if (!s.endsWith('/')) s = '$s/';
    return s;
  }

  static String _keyFromItem(BackupFileItem item) {
    if (item.href.scheme == 's3') {
      return item.href.pathSegments.join('/');
    }
    var path = item.href.path;
    if (path.startsWith('/')) path = path.substring(1);
    return path;
  }

  Future<void> cleanPartials(S3Config cfg) => _client.cleanPartials(cfg);

  Future<void> test(S3Config cfg) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _client.test(cfg);
      _message = 'OK';
    } catch (e) {
      _message = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> backup(
    S3Config cfg, {
    String? password,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    _busy = true;
    _message = null;
    notifyListeners();
    File? file;
    try {
      file = await _dataSync.prepareBackupFile(
        WebDavConfig(scope: cfg.scope),
        password: password,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      final prefix = _normalizePrefix(cfg.prefix);
      final key = '$prefix${p.basename(file.path)}';
      // Use file-stream upload to avoid loading entire ZIP into memory.
      await _client.uploadFile(
        cfg,
        key: key,
        file: file,
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
      await DataSync.cleanupTemporaryBackupFile(file);
      _busy = false;
      notifyListeners();
    }
  }

  Future<List<BackupFileItem>> listRemote(
    S3Config cfg, {
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    return _client.listObjects(
      cfg,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<void> restoreFromItem(
    S3Config cfg,
    BackupFileItem item, {
    RestoreMode mode = RestoreMode.overwrite,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    ForwardCompatibilityPrompt? onForwardCompatibility,
    BackupPasswordPrompt? onPassword,
  }) async {
    _busy = true;
    _message = null;
    notifyListeners();
    File? file;
    try {
      final key = _keyFromItem(item);
      file = await BackupStaging.createDownload();
      // Download directly to file to avoid holding entire object in memory.
      await _client.downloadToFile(
        cfg,
        key: key,
        destination: file,
        onProgress: onProgress,
        cancelToken: cancelToken,
        expectedSize: item.size,
      );
      await _dataSync.restoreFromLocalFile(
        file,
        WebDavConfig(scope: cfg.scope),
        mode: mode,
        onProgress: onProgress,
        cancelToken: cancelToken,
        onForwardCompatibility: onForwardCompatibility,
        onPassword: onPassword,
        requireEncrypted: key.toLowerCase().endsWith('.kbackup'),
      );
      _message = 'Restored';
    } catch (e) {
      if (e is BackupCancelledException) rethrow;
      _message = e.toString();
      rethrow;
    } finally {
      if (file != null) BackupStaging.release(file.path);
      try {
        if (file != null && await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      _busy = false;
      notifyListeners();
    }
  }

  Future<List<BackupFileItem>> deleteAndReload(
    S3Config cfg,
    BackupFileItem item,
  ) async {
    final key = _keyFromItem(item);
    await _client.deleteObject(cfg, key: key);
    return _client.listObjects(cfg);
  }
}
