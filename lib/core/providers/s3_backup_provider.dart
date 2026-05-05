import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/backup.dart';
import '../services/backup/data_sync.dart';
import '../services/backup/s3_client.dart';
import '../services/chat/chat_service.dart';

class S3BackupProvider extends ChangeNotifier {
  final DataSync _dataSync;
  final S3BackupClient _client;

  S3Config _cfg;
  bool _busy = false;
  String? _message;

  S3BackupProvider({required ChatService chatService, S3Config? initialConfig})
    : _dataSync = DataSync(chatService: chatService),
      _client = const S3BackupClient(),
      _cfg = initialConfig ?? const S3Config();

  S3Config get config => _cfg;
  bool get busy => _busy;
  String? get message => _message;

  void updateConfig(S3Config cfg) {
    _cfg = cfg;
    notifyListeners();
  }

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

  Future<Directory> _ensureTempDir() async {
    Directory dir = await getTemporaryDirectory();
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (_) {}
    }
    if (!await dir.exists()) {
      dir = await Directory.systemTemp.createTemp('kelivo_tmp_');
    }
    return dir;
  }

  WebDavConfig _scopeAsWebdavConfig() {
    // DataSync currently uses WebDavConfig for include flags; other fields are ignored.
    return WebDavConfig(
      includeChats: _cfg.includeChats,
      includeFiles: _cfg.includeFiles,
    );
  }

  Future<void> test() async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _client.test(_cfg);
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
      final file = await _dataSync.prepareBackupFile(_scopeAsWebdavConfig());
      final prefix = _normalizePrefix(_cfg.prefix);
      final key = '$prefix${p.basename(file.path)}';
      // Use file-stream upload to avoid loading entire ZIP into memory.
      await _client.uploadFile(_cfg, key: key, file: file);
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

  Future<List<BackupFileItem>> listRemote() async {
    return _client.listObjects(_cfg);
  }

  Future<void> restoreFromItem(
    BackupFileItem item, {
    RestoreMode mode = RestoreMode.overwrite,
  }) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      final key = _keyFromItem(item);
      final tmp = await _ensureTempDir();
      final file = File(p.join(tmp.path, item.displayName));
      // Download directly to file to avoid holding entire object in memory.
      await _client.downloadToFile(_cfg, key: key, destination: file);
      await _dataSync.restoreFromLocalFile(
        file,
        _scopeAsWebdavConfig(),
        mode: mode,
      );
      try {
        await file.delete();
      } catch (_) {}
      _message = 'Restored';
    } catch (e) {
      _message = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<List<BackupFileItem>> deleteAndReload(BackupFileItem item) async {
    final key = _keyFromItem(item);
    await _client.deleteObject(_cfg, key: key);
    return _client.listObjects(_cfg);
  }
}
