import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../database/business_preferences.dart';
import '../database/business_repository.dart';
import '../models/backup.dart';
import '../services/chat/chat_service.dart';
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

  Future<bool> backup() async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _dataSync.backupToWebDav(_cfg);
      _message = 'Backup uploaded';
      return true;
    } catch (e) {
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
  }) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _dataSync.restoreFromWebDav(_cfg, item, mode: mode);
      _message = 'Restored';
    } catch (e) {
      _message = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<List<BackupFileItem>> listRemote() async {
    return _dataSync.listBackupFiles(_cfg);
  }

  Future<List<BackupFileItem>> deleteAndReload(BackupFileItem item) async {
    await _dataSync.deleteWebDavBackupFile(_cfg, item);
    return _dataSync.listBackupFiles(_cfg);
  }

  Future<File> exportToFile() => _dataSync.exportToFile(_cfg);
  Future<void> restoreFromLocalFile(
    File file, {
    RestoreMode mode = RestoreMode.overwrite,
  }) => _dataSync.restoreFromLocalFile(file, _cfg, mode: mode);

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
