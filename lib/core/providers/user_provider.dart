import 'package:flutter/foundation.dart';
import 'dart:io';
import '../database/business_preferences.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../../utils/avatar_cache.dart';
import '../../utils/app_directories.dart';

class UserProvider extends ChangeNotifier {
  static const String _prefsUserNameKey = 'user_name';
  static const String _prefsAvatarTypeKey =
      'avatar_type'; // emoji | url | file | null
  static const String _prefsAvatarValueKey = 'avatar_value';

  final BusinessPreferences preferences;
  String _name = 'User';
  String get name => _name;
  bool _hasSavedName = false;

  String? _avatarType; // 'emoji', 'url', 'file'
  String? _avatarValue;
  String? get avatarType => _avatarType;
  String? get avatarValue => _avatarValue;

  UserProvider({required this.preferences}) {
    _load();
  }

  Future<void> _load() async {
    await preferences.load();
    final n = preferences.getString(_prefsUserNameKey);
    if (n != null && n.isNotEmpty) {
      _name = n;
      _hasSavedName = true;
      notifyListeners();
    }
    _avatarType = preferences.getString(_prefsAvatarTypeKey);
    final rawAvatar = preferences.getString(_prefsAvatarValueKey);
    _avatarValue = rawAvatar == null
        ? null
        : SandboxPathResolver.fix(rawAvatar);
    // Persist the fixed path back if it changed (helps desktop after imports)
    if (rawAvatar != null &&
        _avatarValue != null &&
        rawAvatar != _avatarValue) {
      try {
        await preferences.setString(_prefsAvatarValueKey, _avatarValue!);
      } catch (_) {}
    }
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
    await preferences.setString(_prefsUserNameKey, _name);
  }

  Future<void> setAvatarEmoji(String emoji) async {
    final e = emoji.trim();
    if (e.isEmpty) return;
    _avatarType = 'emoji';
    _avatarValue = e;
    notifyListeners();
    await preferences.setString(_prefsAvatarTypeKey, _avatarType!);
    await preferences.setString(_prefsAvatarValueKey, _avatarValue!);
  }

  Future<void> setAvatarUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    _avatarType = 'url';
    _avatarValue = u;
    notifyListeners();
    await preferences.setString(_prefsAvatarTypeKey, _avatarType!);
    await preferences.setString(_prefsAvatarValueKey, _avatarValue!);
    // Prefetch to enable offline display later
    try {
      await AvatarCache.getPath(u);
    } catch (_) {}
  }

  Future<void> setAvatarFilePath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    final fixedInput = SandboxPathResolver.fix(p);
    // Copy the picked image into app persistent storage so it survives reinstall/update
    try {
      final src = File(fixedInput);
      if (!await src.exists()) return;
      final avatars = await AppDirectories.getAvatarsDirectory();
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
          if ((old.path.contains('/avatars/') ||
                  old.path.contains('\\avatars\\')) &&
              await old.exists()) {
            await old.delete();
          }
        } catch (_) {}
      }

      _avatarType = 'file';
      _avatarValue = dest.path;
      notifyListeners();
      await preferences.setString(_prefsAvatarTypeKey, _avatarType!);
      await preferences.setString(_prefsAvatarValueKey, _avatarValue!);
    } catch (_) {
      // Fallback to original path if copy fails (may still be temporary)
      _avatarType = 'file';
      _avatarValue = fixedInput;
      notifyListeners();
      await preferences.setString(_prefsAvatarTypeKey, _avatarType!);
      await preferences.setString(_prefsAvatarValueKey, _avatarValue!);
    }
  }

  Future<void> resetAvatar() async {
    _avatarType = null;
    _avatarValue = null;
    notifyListeners();
    await preferences.remove(_prefsAvatarTypeKey);
    await preferences.remove(_prefsAvatarValueKey);
  }
}
