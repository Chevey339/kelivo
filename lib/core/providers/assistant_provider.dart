import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../models/assistant.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/avatar_cache.dart';
import '../services/icloud_sync_service.dart';

class AssistantProvider extends ChangeNotifier {
  static const String _assistantsKey = 'assistants_v1';
  static const String _currentAssistantKey = 'current_assistant_id_v1';

  final List<Assistant> _assistants = <Assistant>[];
  String? _currentAssistantId;
  bool _loading = false;
  bool _pendingReload = false;

  List<Assistant> get assistants => List.unmodifiable(_assistants);
  String? get currentAssistantId => _currentAssistantId;
  Assistant? get currentAssistant {
    final idx = _assistants.indexWhere((a) => a.id == _currentAssistantId);
    if (idx != -1) return _assistants[idx];
    if (_assistants.isNotEmpty) return _assistants.first;
    return null;
  }

  AssistantProvider() {
    _load();
    if (ICloudSyncService.instance.isSupported) {
      ICloudSyncService.instance.addListener(_handleICloudUpdate);
    }
  }

  Future<void> _load() async {
    if (_loading) {
      _pendingReload = true;
      return;
    }
    _loading = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_assistantsKey);
    if (raw != null && raw.isNotEmpty) {
      _assistants
        ..clear()
        ..addAll(Assistant.decodeList(raw));
    }
    // Do not create defaults here because localization is not available.
    // Defaults will be ensured later via ensureDefaults(context).
    // Restore current assistant if present
    final savedId = prefs.getString(_currentAssistantKey);
    if (savedId != null && _assistants.any((a) => a.id == savedId)) {
      _currentAssistantId = savedId;
    } else {
      _currentAssistantId = null;
    }
    notifyListeners();
    _loading = false;
    if (_pendingReload) {
      _pendingReload = false;
      unawaited(_load());
    }
  }

  Assistant _defaultAssistant(AppLocalizations l10n) => Assistant(
        id: const Uuid().v4(),
        name: l10n.assistantProviderDefaultAssistantName,
        systemPrompt: '',
        deletable: false,
        thinkingBudget: null,
        temperature: 0.6,
        topP: 1.0,
      );

  // Ensure localized default assistants exist; call this after localization is ready.
  Future<void> ensureDefaults(dynamic context) async {
    if (_assistants.isNotEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    // 1) 默认助手
    _assistants.add(_defaultAssistant(l10n));
    // 2) 示例助手（带提示词模板）
    _assistants.add(Assistant(
      id: const Uuid().v4(),
      name: l10n.assistantProviderSampleAssistantName,
      systemPrompt: l10n.assistantProviderSampleAssistantSystemPrompt(
        '{model_name}',
        '{cur_datetime}',
        '"{locale}"',
        '{timezone}',
        '{device_info}',
        '{system_version}',
      ),
      deletable: false,
      temperature: 0.6,
      topP: 1.0,
    ));
    await _persist();
    // Set current assistant if not set
    if (_currentAssistantId == null && _assistants.isNotEmpty) {
      _currentAssistantId = _assistants.first.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentAssistantKey, _currentAssistantId!);
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString( _assistantsKey, Assistant.encodeList(_assistants));
  }

  void _handleICloudUpdate() {
    unawaited(_load());
  }

  Future<void> setCurrentAssistant(String id) async {
    if (_currentAssistantId == id) return;
    _currentAssistantId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentAssistantKey, id);
  }

  Assistant? getById(String id) {
    final idx = _assistants.indexWhere((a) => a.id == id);
    if (idx == -1) return null;
    return _assistants[idx];
  }

  Future<String> addAssistant({String? name, dynamic context}) async {
    final a = Assistant(
      id: const Uuid().v4(),
      name: (name ?? (context != null
          ? AppLocalizations.of(context)!.assistantProviderNewAssistantName
          : 'New Assistant')),
      temperature: 0.6,
      topP: 1.0,
    );
    _assistants.add(a);
    await _persist();
    notifyListeners();
    return a.id;
  }

  Future<void> updateAssistant(Assistant updated) async {
    final idx = _assistants.indexWhere((a) => a.id == updated.id);
    if (idx == -1) return;

    var next = updated;

    // If avatar changed and is a local file path (from gallery/cache),
    // copy it to persistent Documents/avatars and store that path.
    try {
      final prev = _assistants[idx];
      final raw = (updated.avatar ?? '').trim();
      final prevRaw = (prev.avatar ?? '').trim();
      final changed = raw != prevRaw;
      final isLocalPath = raw.isNotEmpty && (raw.startsWith('/') || raw.contains(':')) && !raw.startsWith('http');
      // Skip if it's already under our avatars folder
      if (changed && isLocalPath && !raw.contains('/avatars/')) {
        final fixedInput = SandboxPathResolver.fix(raw);
        final src = File(fixedInput);
        if (await src.exists()) {
          final docs = await getApplicationDocumentsDirectory();
          final avatarsDir = Directory('${docs.path}/avatars');
          if (!await avatarsDir.exists()) {
            await avatarsDir.create(recursive: true);
          }
          String ext = '';
          final dot = fixedInput.lastIndexOf('.');
          if (dot != -1 && dot < fixedInput.length - 1) {
            ext = fixedInput.substring(dot + 1).toLowerCase();
            if (ext.length > 6) ext = 'jpg';
          } else {
            ext = 'jpg';
          }
          final filename = 'assistant_${updated.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final dest = File('${avatarsDir.path}/$filename');
          await src.copy(dest.path);

          // Optionally remove old stored avatar if it lives in our avatars folder
          if (prevRaw.isNotEmpty && prevRaw.contains('/avatars/')) {
            try {
              final old = File(prevRaw);
              if (await old.exists() && old.path != dest.path) {
                await old.delete();
              }
            } catch (_) {}
          }

          next = updated.copyWith(avatar: dest.path);
        }
      }

      // Prefetch URL avatar to allow offline display later
      if (changed && raw.startsWith('http')) {
        try { await AvatarCache.getPath(raw); } catch (_) {}
      }

      // Handle background persistence similar to avatar, but under images/
      final bgRaw = (updated.background ?? '').trim();
      final prevBgRaw = (prev.background ?? '').trim();
      final bgChanged = bgRaw != prevBgRaw;
      final bgIsLocal = bgRaw.isNotEmpty && (bgRaw.startsWith('/') || bgRaw.contains(':')) && !bgRaw.startsWith('http');
      if (bgChanged && bgIsLocal && !bgRaw.contains('/images/')) {
        final fixedBg = SandboxPathResolver.fix(bgRaw);
        final srcBg = File(fixedBg);
        if (await srcBg.exists()) {
          final docs = await getApplicationDocumentsDirectory();
          final imagesDir = Directory('${docs.path}/images');
          if (!await imagesDir.exists()) {
            await imagesDir.create(recursive: true);
          }
          String ext = '';
          final dot = fixedBg.lastIndexOf('.');
          if (dot != -1 && dot < fixedBg.length - 1) {
            ext = fixedBg.substring(dot + 1).toLowerCase();
            if (ext.length > 6) ext = 'jpg';
          } else {
            ext = 'jpg';
          }
          final filename = 'background_${updated.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final destBg = File('${imagesDir.path}/$filename');
          await srcBg.copy(destBg.path);

          // Clean old stored background if it lived in images/
          if (prevBgRaw.isNotEmpty && prevBgRaw.contains('/images/')) {
            try {
              final oldBg = File(prevBgRaw);
              if (await oldBg.exists() && oldBg.path != destBg.path) {
                await oldBg.delete();
              }
            } catch (_) {}
          }

          next = next.copyWith(background: destBg.path);
        }
      } else if (bgChanged && bgRaw.isEmpty && prevBgRaw.contains('/images/')) {
        // If background cleared, optionally remove previous stored file
        try {
          final oldBg = File(prevBgRaw);
          if (await oldBg.exists()) {
            await oldBg.delete();
          }
        } catch (_) {}
      }
    } catch (_) {
      // On any failure, fall back to the provided value unchanged.
    }

    _assistants[idx] = next;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteAssistant(String id) async {
    final idx = _assistants.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    if (!_assistants[idx].deletable) return; // default not deletable
    final removingCurrent = _assistants[idx].id == _currentAssistantId;
    _assistants.removeAt(idx);
    if (removingCurrent) {
      _currentAssistantId = _assistants.isNotEmpty ? _assistants.first.id : null;
    }
    await _persist();
    final prefs = await SharedPreferences.getInstance();
    if (_currentAssistantId != null) {
      await prefs.setString(_currentAssistantKey, _currentAssistantId!);
    } else {
      await prefs.remove(_currentAssistantKey);
    }
    notifyListeners();
  }

  Future<void> reorderAssistants(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _assistants.length) return;
    if (newIndex < 0 || newIndex >= _assistants.length) return;
    
    final assistant = _assistants.removeAt(oldIndex);
    _assistants.insert(newIndex, assistant);
    
    // Notify listeners immediately for smooth UI update
    notifyListeners();
    
    // Then persist the changes
    await _persist();
  }

  @override
  void dispose() {
    if (ICloudSyncService.instance.isSupported) {
      ICloudSyncService.instance.removeListener(_handleICloudUpdate);
    }
    super.dispose();
  }
}
