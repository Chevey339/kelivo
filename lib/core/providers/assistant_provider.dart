import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../database/chat_database_repository.dart';
import '../services/chat/chat_service.dart';
import '../models/assistant.dart';
import '../models/assistant_regex.dart';
import '../models/preset_message.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/avatar_cache.dart';
import '../../utils/app_directories.dart';
import '../services/proactive_care_alarm_service.dart';

class AssistantProvider extends ChangeNotifier {
  static const String _assistantsKey = 'assistants_v1';
  static const String _currentAssistantKey = 'current_assistant_id_v1';
  static const String _legacySearchEnabledKey = 'search_enabled_v1';

  ChatDatabaseRepository? get _repo {
    if (chatService == null || !chatService!.initialized) return null;
    return chatService!.repo;
  }

  final List<Assistant> _assistants = <Assistant>[];
  String? _currentAssistantId;
  final ChatService? chatService;
  bool _loaded = false;

  List<Assistant> get assistants => List.unmodifiable(_assistants);
  String? get currentAssistantId => _currentAssistantId;
  Assistant? get currentAssistant {
    final idx = _assistants.indexWhere((a) => a.id == _currentAssistantId);
    if (idx != -1) return _assistants[idx];
    if (_assistants.isNotEmpty) return _assistants.first;
    return null;
  }

  bool get isLoaded => _loaded;
  bool get currentSearchEnabled => currentAssistant?.searchEnabled ?? false;

  AssistantProvider({this.chatService});

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final repo = _repo;
    if (repo == null) return;
    await _doLoad(repo);
  }

  @visibleForTesting
  Future<void> loadFromPrefs() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_assistantsKey);
    if (raw != null && raw.isNotEmpty) {
      final legacySearchEnabled = prefs.getBool(_legacySearchEnabledKey);
      final migrated = _decodeAssistantsWithLegacySearch(
        raw,
        legacySearchEnabled: legacySearchEnabled,
      );
      _assistants
        ..clear()
        ..addAll(migrated.assistants);
    }
    if (_assistants.isEmpty) return;
    _loaded = true;
    final savedId = prefs.getString(_currentAssistantKey);
    if (savedId != null && _assistants.any((a) => a.id == savedId)) {
      _currentAssistantId = savedId;
    }
    notifyListeners();
  }

  Future<void> _doLoad(ChatDatabaseRepository repo) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = await repo.getAllAssistants();
    if (rows.isNotEmpty) {
      _assistants
        ..clear()
        ..addAll(rows);
    } else {
      await _migrateFromPrefs(prefs, repo);
    }

    if (_assistants.isEmpty) return;

    _loaded = true;
    final savedId = prefs.getString(_currentAssistantKey);
    if (savedId != null && _assistants.any((a) => a.id == savedId)) {
      _currentAssistantId = savedId;
    }
    notifyListeners();
  }

  Future<void> _migrateFromPrefs(
    SharedPreferences prefs,
    ChatDatabaseRepository? repo,
  ) async {
    final raw = prefs.getString(_assistantsKey);
    if (raw == null || raw.isEmpty) return;

    final legacySearchEnabled = prefs.getBool(_legacySearchEnabledKey);
    final migrated = _decodeAssistantsWithLegacySearch(
      raw,
      legacySearchEnabled: legacySearchEnabled,
    );
    bool changed = migrated.didApplyLegacySearch;
    _assistants
      ..clear()
      ..addAll(migrated.assistants);

    for (int i = 0; i < _assistants.length; i++) {
      final a = _assistants[i];
      String? av = a.avatar;
      String? bg = a.background;
      bool dirty = false;
      if (av != null &&
          av.isNotEmpty &&
          (av.startsWith('/') || av.contains(':')) &&
          !av.startsWith('http')) {
        final fixed = SandboxPathResolver.fix(av);
        if (fixed != av) {
          av = fixed;
          dirty = true;
        }
      }
      if (bg != null &&
          bg.isNotEmpty &&
          (bg.startsWith('/') || bg.contains(':')) &&
          !bg.startsWith('http')) {
        final fixedBg = SandboxPathResolver.fix(bg);
        if (fixedBg != bg) {
          bg = fixedBg;
          dirty = true;
        }
      }
      if (dirty) {
        _assistants[i] = a.copyWith(avatar: av, background: bg);
        changed = true;
      }
    }

    if (repo != null) {
      try {
        await repo.putAssistants(_assistants);
        await prefs.remove(_assistantsKey);
        await prefs.remove(_legacySearchEnabledKey);
      } catch (_) {}
    } else if (changed) {
      await prefs.setString(_assistantsKey, Assistant.encodeList(_assistants));
    }
  }

  _AssistantDecodeResult _decodeAssistantsWithLegacySearch(
    String raw, {
    required bool? legacySearchEnabled,
  }) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      bool didApplyLegacySearch = false;
      final assistants = [
        for (final e in decoded)
          if (e is Map)
            (() {
              final json = e.cast<String, dynamic>();
              if (legacySearchEnabled != null &&
                  !json.containsKey('searchEnabled')) {
                json['searchEnabled'] = legacySearchEnabled;
                didApplyLegacySearch = true;
              }
              return Assistant.fromJson(json);
            })(),
      ];
      return _AssistantDecodeResult(
        assistants: assistants,
        didApplyLegacySearch: didApplyLegacySearch,
      );
    } catch (_) {
      return const _AssistantDecodeResult(
        assistants: <Assistant>[],
        didApplyLegacySearch: false,
      );
    }
  }

  Assistant _defaultAssistant(AppLocalizations l10n) => Assistant(
    id: const Uuid().v4(),
    name: l10n.assistantProviderDefaultAssistantName,
    systemPrompt: '',
    thinkingBudget: null,
    temperature: 0.6,
    topP: null,
  );

  // Ensure localized default assistants exist; call this after localization is ready.
  Future<void> ensureDefaults(dynamic context) async {
    await ensureLoaded();
    if (_assistants.isNotEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    // 1) 默认助手
    _assistants.add(_defaultAssistant(l10n));
    // 2) 示例助手（带提示词模板）
    _assistants.add(
      Assistant(
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
        temperature: 0.6,
        topP: null,
      ),
    );
    await _persist();
    // Set current assistant if not set
    if (_currentAssistantId == null && _assistants.isNotEmpty) {
      _currentAssistantId = _assistants.first.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentAssistantKey, _currentAssistantId!);
    }
    notifyListeners();
  }

  String _buildCopyName(Assistant source, AppLocalizations? l10n) {
    final suffix = (l10n?.assistantSettingsCopySuffix ?? 'Copy').trim();
    final baseName = source.name.trim().isEmpty
        ? (l10n?.assistantProviderNewAssistantName ?? 'Assistant')
        : source.name.trim();
    final existingNames = _assistants.map((a) => a.name).toSet();

    String candidate = suffix.isEmpty ? baseName : '$baseName $suffix';
    int counter = 2;
    while (existingNames.contains(candidate)) {
      final counterSuffix = suffix.isEmpty ? '$counter' : '$suffix $counter';
      candidate = '$baseName $counterSuffix';
      counter++;
    }
    return candidate;
  }

  Future<String?> _duplicateLocalFile(
    String? rawPath, {
    required bool isAvatar,
    required String newId,
  }) async {
    final raw = (rawPath ?? '').trim();
    if (raw.isEmpty) return rawPath;
    if (raw.startsWith('http') || raw.startsWith('data:')) return rawPath;
    final fixed = SandboxPathResolver.fix(raw);
    final src = File(fixed);
    if (!await src.exists()) return rawPath;

    try {
      final dir = isAvatar
          ? await AppDirectories.getAvatarsDirectory()
          : await AppDirectories.getImagesDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      String ext = '';
      final dot = fixed.lastIndexOf('.');
      if (dot != -1 && dot < fixed.length - 1) {
        ext = fixed.substring(dot + 1).toLowerCase();
        if (ext.length > 6) ext = 'jpg';
      } else {
        ext = 'jpg';
      }
      final prefix = isAvatar ? 'assistant' : 'background';
      final dest = File(
        '${dir.path}/${prefix}_${newId}_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await src.copy(dest.path);
      return dest.path;
    } catch (_) {
      return rawPath;
    }
  }

  Future<String?> _copyLocalAssetToManagedDirectory(
    String? rawPath, {
    required Future<Directory> Function() directoryAsync,
    required String filenamePrefix,
    required String id,
  }) async {
    final raw = (rawPath ?? '').trim();
    if (raw.isEmpty || raw.startsWith('http') || raw.startsWith('data:')) {
      return rawPath;
    }
    if (!(raw.startsWith('/') || raw.contains(':'))) return rawPath;

    final fixed = SandboxPathResolver.fix(raw);
    final src = File(fixed);
    if (!await src.exists()) return rawPath;

    final managedDir = await directoryAsync();
    final managedRoot = p.normalize(managedDir.absolute.path);
    final sourcePath = p.normalize(src.absolute.path);
    if (p.isWithin(managedRoot, sourcePath)) return fixed;

    if (!await managedDir.exists()) {
      await managedDir.create(recursive: true);
    }

    var ext = p.extension(fixed).toLowerCase();
    if (ext.isEmpty || ext.length > 7) ext = '.jpg';
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final dest = File(
      p.join(
        managedDir.path,
        '${filenamePrefix}_${safeId}_${DateTime.now().millisecondsSinceEpoch}$ext',
      ),
    );
    await src.copy(dest.path);
    return dest.path;
  }

  Future<void> _deleteManagedFileIfOwned(
    String? rawPath, {
    required Future<Directory> Function() directoryAsync,
    required String? replacementPath,
  }) async {
    final raw = (rawPath ?? '').trim();
    if (raw.isEmpty) return;
    try {
      final dir = await directoryAsync();
      final root = p.normalize(dir.absolute.path);
      final targetFile = File(raw);
      final target = p.normalize(targetFile.absolute.path);
      if (!p.isWithin(root, target)) return;
      if (replacementPath != null &&
          p.equals(target, p.normalize(File(replacementPath).absolute.path))) {
        return;
      }
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    final repo = _repo;
    final prefs = await SharedPreferences.getInstance();
    if (repo != null) {
      await repo.putAssistants(_assistants);
      await prefs.remove(_assistantsKey);
      await prefs.remove(_legacySearchEnabledKey);
    } else {
      await prefs.setString(_assistantsKey, Assistant.encodeList(_assistants));
    }
  }

  Future<void> _persistSingle(Assistant a, {int? sortOrder}) async {
    final repo = _repo;
    if (repo != null) {
      await repo.putAssistant(a, sortOrder: sortOrder);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_assistantsKey);
      await prefs.remove(_legacySearchEnabledKey);
    } else {
      await _persist();
    }
  }

  Future<void> _deleteSingle(String id) async {
    final repo = _repo;
    if (repo != null) {
      await repo.deleteAssistant(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_assistantsKey);
      await prefs.remove(_legacySearchEnabledKey);
    } else {
      await _persist();
    }
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

  // Lightweight accessor so callers don't depend on Assistant.presetMessages symbol
  List<Map<String, String>> getPresetMessagesForAssistant(String? assistantId) {
    Assistant? a;
    if (assistantId != null) {
      a = getById(assistantId);
    } else {
      a = currentAssistant;
    }
    if (a == null) return const <Map<String, String>>[];
    return [
      for (final m in a.presetMessages) {'role': m.role, 'content': m.content},
    ];
  }

  Future<String> addAssistant({String? name, dynamic context}) async {
    final a = Assistant(
      id: const Uuid().v4(),
      name:
          (name ??
          (context != null
              ? AppLocalizations.of(context)!.assistantProviderNewAssistantName
              : 'New Assistant')),
      temperature: 0.6,
      topP: null,
    );
    _assistants.add(a);
    await _persistSingle(a, sortOrder: _assistants.length - 1);
    notifyListeners();
    return a.id;
  }

  Future<String?> duplicateAssistant(
    String id, {
    AppLocalizations? l10n,
  }) async {
    final idx = _assistants.indexWhere((a) => a.id == id);
    if (idx == -1) return null;
    final source = _assistants[idx];
    final newId = const Uuid().v4();

    final avatarCopy = await _duplicateLocalFile(
      source.avatar,
      isAvatar: true,
      newId: newId,
    );
    final backgroundCopy = await _duplicateLocalFile(
      source.background,
      isAvatar: false,
      newId: newId,
    );

    final copy = source.copyWith(
      id: newId,
      name: _buildCopyName(source, l10n),
      avatar: avatarCopy,
      background: backgroundCopy,
      mcpServerIds: List<String>.of(source.mcpServerIds),
      localToolIds: List<String>.of(source.localToolIds),
      customHeaders: source.customHeaders
          .map((e) => Map<String, String>.from(e))
          .toList(),
      customBody: source.customBody
          .map((e) => Map<String, String>.from(e))
          .toList(),
      presetMessages: source.presetMessages
          .map((m) => PresetMessage(role: m.role, content: m.content))
          .toList(),
      regexRules: source.regexRules
          .map(
            (r) => AssistantRegex(
              id: const Uuid().v4(),
              name: r.name,
              pattern: r.pattern,
              replacement: r.replacement,
              scopes: List<AssistantRegexScope>.of(r.scopes),
              visualOnly: r.visualOnly,
              replaceOnly: r.replaceOnly,
              enabled: r.enabled,
            ),
          )
          .toList(),
    );

    _assistants.insert(idx + 1, copy);
    await _persistSingle(copy, sortOrder: idx + 1);
    notifyListeners();
    return copy.id;
  }

  Future<void> updateAssistant(Assistant updated) async {
    final idx = _assistants.indexWhere((a) => a.id == updated.id);
    if (idx == -1) return;

    final prev = _assistants[idx];
    var next = updated;

    try {
      final raw = (updated.avatar ?? '').trim();
      final prevRaw = (prev.avatar ?? '').trim();
      final changed = raw != prevRaw;

      if (changed) {
        final avatarPath = await _copyLocalAssetToManagedDirectory(
          raw,
          directoryAsync: AppDirectories.getAvatarsDirectory,
          filenamePrefix: 'assistant',
          id: updated.id,
        );
        if (avatarPath != updated.avatar) {
          await _deleteManagedFileIfOwned(
            prevRaw,
            directoryAsync: AppDirectories.getAvatarsDirectory,
            replacementPath: avatarPath,
          );
          next = updated.copyWith(avatar: avatarPath);
        } else if (raw.isEmpty) {
          await _deleteManagedFileIfOwned(
            prevRaw,
            directoryAsync: AppDirectories.getAvatarsDirectory,
            replacementPath: null,
          );
        }
      }

      // Prefetch URL avatar to allow offline display later
      if (changed && raw.startsWith('http')) {
        try {
          await AvatarCache.getPath(raw);
        } catch (_) {}
      }

      // Handle background persistence similar to avatar, but under images/
      final bgRaw = (updated.background ?? '').trim();
      final prevBgRaw = (prev.background ?? '').trim();
      final bgChanged = bgRaw != prevBgRaw;
      if (bgChanged) {
        final backgroundPath = await _copyLocalAssetToManagedDirectory(
          bgRaw,
          directoryAsync: AppDirectories.getImagesDirectory,
          filenamePrefix: 'background',
          id: updated.id,
        );
        if (backgroundPath != updated.background) {
          await _deleteManagedFileIfOwned(
            prevBgRaw,
            directoryAsync: AppDirectories.getImagesDirectory,
            replacementPath: backgroundPath,
          );
          next = next.copyWith(background: backgroundPath);
        } else if (bgRaw.isEmpty) {
          await _deleteManagedFileIfOwned(
            prevBgRaw,
            directoryAsync: AppDirectories.getImagesDirectory,
            replacementPath: null,
          );
        }
      }
    } catch (_) {
      // On any failure, fall back to the provided value unchanged.
    }

    _assistants[idx] = next;
    await _persistSingle(next, sortOrder: idx);
    notifyListeners();
    _syncProactiveCareAlarm(prev, next);
  }

  /// Schedule or cancel the proactive care alarm when relevant fields change.
  void _syncProactiveCareAlarm(Assistant prev, Assistant next) {
    if (!Platform.isAndroid || !ProactiveCareAlarmService.isSupported) return;
    final wasEnabled = prev.enableProactiveCare;
    final isEnabled = next.enableProactiveCare;
    final timeChanged =
        prev.proactiveCareNextMessageAt != next.proactiveCareNextMessageAt;
    if (!isEnabled && wasEnabled) {
      ProactiveCareAlarmService.cancelFor(next.id);
    } else if (isEnabled && (!wasEnabled || timeChanged)) {
      final at = next.proactiveCareNextMessageAt;
      if (at != null) {
        ProactiveCareAlarmService.sync(next);
      }
    }
  }

  Future<void> setSearchEnabledForCurrentAssistant(bool enabled) async {
    final a = currentAssistant;
    if (a == null || a.searchEnabled == enabled) return;
    await updateAssistant(a.copyWith(searchEnabled: enabled));
  }

  Future<void> reorderAssistantRegex({
    required String assistantId,
    required int oldIndex,
    required int newIndex,
  }) async {
    final idx = _assistants.indexWhere((a) => a.id == assistantId);
    if (idx == -1) return;
    final list = List<AssistantRegex>.of(_assistants[idx].regexRules);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    final updated = _assistants[idx].copyWith(regexRules: list);
    _assistants[idx] = updated;
    notifyListeners();
    await _persistSingle(updated, sortOrder: idx);
  }

  Future<bool> deleteAssistant(String id) async {
    final idx = _assistants.indexWhere((a) => a.id == id);
    if (idx == -1) return false;
    // Do not allow deleting the last remaining assistant
    if (_assistants.length <= 1) return false;

    await chatService?.deleteConversationsForAssistant(id);
    // Cancel any pending proactive care alarm for this assistant.
    if (Platform.isAndroid && ProactiveCareAlarmService.isSupported) {
      ProactiveCareAlarmService.cancelFor(id);
    }

    final removingCurrent = _assistants[idx].id == _currentAssistantId;
    _assistants.removeAt(idx);
    if (removingCurrent) {
      _currentAssistantId = _assistants.isNotEmpty
          ? _assistants.first.id
          : null;
    }
    await _deleteSingle(id);
    final prefs = await SharedPreferences.getInstance();
    if (_currentAssistantId != null) {
      await prefs.setString(_currentAssistantKey, _currentAssistantId!);
    } else {
      await prefs.remove(_currentAssistantKey);
    }
    notifyListeners();
    return true;
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

  // Reorder only within a subset (e.g., assistants belonging to a tag group or ungrouped).
  // subsetIds defines the set and order boundary; other assistants remain in place.
  Future<void> reorderAssistantsWithin({
    required List<String> subsetIds,
    required int oldIndex,
    required int newIndex,
  }) async {
    if (oldIndex == newIndex) return;
    if (subsetIds.isEmpty) return;

    // Build subset indices in the master list preserving current order
    final idSet = subsetIds.toSet();
    final subsetIndices = <int>[];
    for (int i = 0; i < _assistants.length; i++) {
      if (idSet.contains(_assistants[i].id)) subsetIndices.add(i);
    }
    if (subsetIndices.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= subsetIndices.length) return;
    if (newIndex < 0 || newIndex >= subsetIndices.length) return;

    // Extract subset in current order
    final subset = subsetIndices
        .map((i) => _assistants[i])
        .toList(growable: true);
    final moved = subset.removeAt(oldIndex);
    subset.insert(newIndex, moved);

    // Merge back into master list
    final merged = <Assistant>[];
    int take = 0;
    for (int i = 0; i < _assistants.length; i++) {
      final a = _assistants[i];
      if (idSet.contains(a.id)) {
        merged.add(subset[take++]);
      } else {
        merged.add(a);
      }
    }
    _assistants
      ..clear()
      ..addAll(merged);

    notifyListeners();
    await _persist();
  }
}

class _AssistantDecodeResult {
  const _AssistantDecodeResult({
    required this.assistants,
    required this.didApplyLegacySearch,
  });

  final List<Assistant> assistants;
  final bool didApplyLegacySearch;
}
