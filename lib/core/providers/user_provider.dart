import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../../utils/avatar_cache.dart';
import '../services/icloud_sync_service.dart';

class UserProvider extends ChangeNotifier {
  static const String _prefsUserNameKey = 'user_name';
  static const String _prefsAvatarTypeKey = 'avatar_type'; // emoji | url | file | null
  static const String _prefsAvatarValueKey = 'avatar_value';

  String _name = 'User';
  String get name => _name;
  bool _hasSavedName = false;

  String? _avatarType; // 'emoji', 'url', 'file'
  String? _avatarValue;
  String? get avatarType => _avatarType;
  String? get avatarValue => _avatarValue;

  UserProvider() {
    _load();
    if (ICloudSyncService.instance.isSupported) {
      ICloudSyncService.instance.addListener(_handleICloudUpdate);
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getString(_prefsUserNameKey);
    if (n != null && n.isNotEmpty) {
      _name = n;
      _hasSavedName = true;
      notifyListeners();
    }
    _avatarType = prefs.getString(_prefsAvatarTypeKey);
    final rawAvatar = prefs.getString(_prefsAvatarValueKey);
    _avatarValue = rawAvatar == null ? null : SandboxPathResolver.fix(rawAvatar);
    // Only notify if avatar exists; otherwise rely on name notify above
    if (_avatarType != null && _avatarValue != null) {
      notifyListeners();
    }
  }

  // Set localized default name if user hasn't saved a custom one
  void setDefaultNameIfUnset(String localizedDefaultName) {
    if (_hasSavedName) return;
    final v = localizedDefaultName.trim();
    if (v.isEmpty) return;
    if (_name != v) {
      _name = v;
      notifyListeners();
    }
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _name) return;
    _name = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUserNameKey, _name);
  }

  Future<void> setAvatarEmoji(String emoji) async {
    final e = emoji.trim();
    if (e.isEmpty) return;
    _avatarType = 'emoji';
    _avatarValue = e;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
    await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
  }

  Future<void> setAvatarUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    _avatarType = 'url';
    _avatarValue = u;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
    await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
    // Prefetch to enable offline display later
    try { await AvatarCache.getPath(u); } catch (_) {}
  }

  Future<void> setAvatarFilePath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    final fixedInput = SandboxPathResolver.fix(p);
    // Copy the picked image into app persistent storage so it survives reinstall/update
    try {
      final src = File(fixedInput);
      if (!await src.exists()) return;
      final dir = await getApplicationDocumentsDirectory();
      final avatars = Directory('${dir.path}/avatars');
      if (!await avatars.exists()) {
        await avatars.create(recursive: true);
      }
      String ext = '';
      final dot = fixedInput.lastIndexOf('.');
      if (dot != -1 && dot < p.length - 1) {
        ext = fixedInput.substring(dot + 1).toLowerCase();
        // Basic sanitize
        if (ext.length > 6) ext = 'jpg';
      } else {
        ext = 'jpg';
      }
      final filename = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final dest = File('${avatars.path}/$filename');
      await src.copy(dest.path);

      // Optionally clean old local avatar if it was stored inside our avatars folder
      if (_avatarType == 'file' && _avatarValue != null) {
        try {
          final old = File(_avatarValue!);
          if (old.path.contains('/avatars/') && await old.exists()) {
            await old.delete();
          }
        } catch (_) {}
      }

      _avatarType = 'file';
      _avatarValue = dest.path;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
      await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
    } catch (_) {
      // Fallback to original path if copy fails (may still be temporary)
      _avatarType = 'file';
      _avatarValue = fixedInput;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
      await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
    }
  }

  Future<void> resetAvatar() async {
    _avatarType = null;
    _avatarValue = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsAvatarTypeKey);
    await prefs.remove(_prefsAvatarValueKey);
  }

  Future<void> _reloadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getString(_prefsUserNameKey);
    bool didChange = false;
    if (n != null && n.isNotEmpty && n != _name) {
      _name = n;
      _hasSavedName = true;
      didChange = true;
    }
    final newType = prefs.getString(_prefsAvatarTypeKey);
    final rawAvatar = prefs.getString(_prefsAvatarValueKey);
    final fixed = rawAvatar == null ? null : SandboxPathResolver.fix(rawAvatar);
    if (newType != _avatarType || fixed != _avatarValue) {
      _avatarType = newType;
      _avatarValue = fixed;
      didChange = true;
    }
    if (didChange) {
      notifyListeners();
    }
  }

  void _handleICloudUpdate() {
    unawaited(_reloadFromPrefs());
  }

  @override
  void dispose() {
    if (ICloudSyncService.instance.isSupported) {
      ICloudSyncService.instance.removeListener(_handleICloudUpdate);
    }
    super.dispose();
  }
}
