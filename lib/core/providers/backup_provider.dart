import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/backup.dart';
import '../services/chat/chat_service.dart';
import '../services/backup/data_sync.dart';

class BackupProvider extends ChangeNotifier {
  final DataSync _dataSync;
  WebDavConfig _cfg;
  bool _busy = false;
  String? _message;

  BackupProvider({required ChatService chatService, WebDavConfig? initialConfig})
      : _dataSync = DataSync(chatService: chatService),
        _cfg = initialConfig ?? const WebDavConfig();

  WebDavConfig get config => _cfg;
  bool get busy => _busy;
  String? get message => _message;

  void updateConfig(WebDavConfig cfg) {
    _cfg = cfg;
    notifyListeners();
  }

  Future<void> test() async {
    _busy = true; _message = null; notifyListeners();
    try {
      await _dataSync.testWebdav(_cfg);
      _message = 'OK';
    } catch (e) {
      _message = e.toString();
    } finally {
      _busy = false; notifyListeners();
    }
  }

  Future<void> backup() async {
    _busy = true; _message = null; notifyListeners();
    try {
      await _dataSync.backupToWebDav(_cfg);
      _message = 'Backup uploaded';
    } catch (e) {
      _message = e.toString();
    } finally {
      _busy = false; notifyListeners();
    }
  }

  Future<void> restoreFromItem(BackupFileItem item, {RestoreOptions? options, RestoreMode mode = RestoreMode.overwrite}) async {
    _busy = true; _message = null; notifyListeners();
    try { await _dataSync.restoreFromWebDav(_cfg, item, options: options, mode: mode); _message = 'Restored'; }
    catch (e) { _message = e.toString(); }
    finally { _busy = false; notifyListeners(); }
  }

  Future<List<BackupFileItem>> listRemote() async {
    return _dataSync.listBackupFiles(_cfg);
  }

  Future<List<BackupFileItem>> deleteAndReload(BackupFileItem item) async {
    await _dataSync.deleteWebDavBackupFile(_cfg, item);
    return _dataSync.listBackupFiles(_cfg);
  }

  Future<File> exportToFile() => _dataSync.exportToFile(_cfg);
  Future<void> restoreFromLocalFile(File file, {RestoreOptions? options, RestoreMode mode = RestoreMode.overwrite}) => _dataSync.restoreFromLocalFile(file, _cfg, options: options, mode: mode);
}

