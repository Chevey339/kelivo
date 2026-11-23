import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show StringCharacters;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/business_preferences.dart';
import '../../../core/database/business_settings_router.dart';
import '../../../core/models/media_creation.dart';
import '../../../core/models/model_spec.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/media/media_generation_runner.dart';
import '../../../core/services/media/media_request.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../core/services/storage/attachment_file_lock.dart';

class MediaModelChoice {
  const MediaModelChoice(this.provider, this.spec, this.capabilities);

  final ProviderConfig provider;
  final ModelSpec spec;
  final MediaCapabilities capabilities;
  String get key => '${provider.id}::${spec.id}';
}

class CreationDraft {
  const CreationDraft({
    this.prompt = '',
    this.references = const [],
    this.videoFrames = false,
  });

  final String prompt;
  final List<MediaReference> references;
  final bool videoFrames;

  CreationDraft copyWith({
    String? prompt,
    List<MediaReference>? references,
    bool? videoFrames,
  }) => CreationDraft(
    prompt: prompt ?? this.prompt,
    references: references == null
        ? this.references
        : List.unmodifiable(references),
    videoFrames: videoFrames ?? this.videoFrames,
  );
}

typedef _ComposerOptions = ({
  String? model,
  String ratio,
  int count,
  int? duration,
  String? resolution,
});

class MediaCreationController extends ChangeNotifier {
  MediaCreationController({
    required this.runner,
    required this.settings,
    required this.preferences,
  }) {
    _options.addAll(_readOptions());
    _topicsSubscription = runner.repository.watchTopics().listen((topics) {
      _topics = topics;
      notifyListeners();
    }, onError: _storageError);
    _batchesSubscription = runner.repository.watchBatches().listen((batches) {
      _batches = batches;
      _batchesByTopic.clear();
      for (final batch in batches) {
        final id = batch.topicId;
        if (id != null) (_batchesByTopic[id] ??= []).add(batch);
      }
      notifyListeners();
    }, onError: _storageError);
    _itemsSubscription = runner.repository.watchItems().listen((items) {
      _itemsByBatch.clear();
      for (final item in items) {
        (_itemsByBatch[item.batchId] ??= []).add(item);
      }
      for (final items in _itemsByBatch.values) {
        items.sort((left, right) => left.ordinal.compareTo(right.ordinal));
      }
      notifyListeners();
    }, onError: _storageError);
    settings.addListener(_settingsChanged);
  }

  final MediaGenerationRunner runner;
  final SettingsProvider settings;
  final BusinessPreferences preferences;
  late final StreamSubscription<List<GenerationTopicRow>> _topicsSubscription;
  late final StreamSubscription<List<GenerationBatchRow>> _batchesSubscription;
  late final StreamSubscription<List<GenerationItemRow>> _itemsSubscription;
  List<GenerationTopicRow> _topics = const [];
  List<GenerationBatchRow> _batches = const [];
  final _batchesByTopic = <String, List<GenerationBatchRow>>{};
  final _itemsByBatch = <String, List<GenerationItemRow>>{};
  final _drafts = <String?, CreationDraft>{};
  final _options = <MediaMode, _ComposerOptions>{};
  final _choices = <MediaMode, List<MediaModelChoice>>{};
  final _work = <String?>{};
  final _deletingTopics = <String>{};
  final _namingTopics = <String>{};
  MediaMode _mode = MediaMode.image;
  bool _disposed = false;

  MediaMode get mode => _mode;
  List<GenerationTopicRow> get topics => _topics;
  GenerationTopicRow? topic(String id) =>
      _topics.where((row) => row.id == id).firstOrNull;
  List<GenerationBatchRow> batchesFor(String id) =>
      _batchesByTopic[id] ?? const [];
  List<GenerationItemRow> itemsFor(String id) => _itemsByBatch[id] ?? const [];
  List<GenerationItemRow> worksFor(String id) => [
    for (final batch in batchesFor(id)) ...itemsFor(batch.id),
  ];
  CreationDraft draftFor(String? topicId) =>
      _drafts[topicId] ?? const CreationDraft();
  bool submitting(String? topicId) => _work.contains(topicId);
  bool namingTopic(String id) => _namingTopics.contains(id);
  bool get autoTitle =>
      preferences.getBool(BusinessKeyRegistry.creationAutoTitleKey) ?? true;

  Iterable<GenerationTopicRow> searchTopics(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return _topics;
    return _topics.where(
      (topic) =>
          topic.title.toLowerCase().contains(term) ||
          batchesFor(
            topic.id,
          ).any((batch) => batch.prompt.toLowerCase().contains(term)),
    );
  }

  List<MediaModelChoice> get models => _choices.putIfAbsent(_mode, () {
    final keys = {...settings.providersOrder, ...settings.providerConfigs.keys};
    return [
      for (final id in keys)
        ..._modelsForProvider(
          settings.getProviderConfig(id, defaultName: id),
          _mode,
        ),
    ];
  });

  Iterable<MediaModelChoice> _modelsForProvider(
    ProviderConfig provider,
    MediaMode mode,
  ) sync* {
    if (!provider.enabled ||
        provider.isOAuth && provider.oauthCredentials?.requiresLogin != false) {
      return;
    }
    for (final id in provider.enabledModels) {
      final spec = ModelSpecResolver.instance.spec(provider, id);
      final eligible = mode == MediaMode.video
          ? spec.type == ModelType.video
          : spec.type == ModelType.image;
      if (!eligible) continue;
      final caps = runner.capabilities(provider, mode, id);
      if (caps != null) yield MediaModelChoice(provider, spec, caps);
    }
  }

  _ComposerOptions get _currentOptions =>
      _options[_mode] ??
      (model: null, ratio: 'auto', count: 1, duration: null, resolution: null);
  MediaModelChoice? get model =>
      models
          .where((choice) => choice.key == _currentOptions.model)
          .firstOrNull ??
      models.firstOrNull;
  int get count => mode == MediaMode.video ? 1 : _currentOptions.count;
  List<String> ratiosFor(String? topicId) {
    final caps = model?.capabilities;
    if (caps == null ||
        (caps.framesUseAutomaticRatio && showsFrames(topicId))) {
      return const ['auto'];
    }
    return caps.ratiosFor(resolutionFor(topicId));
  }

  String ratioFor(String? topicId) {
    final ratios = ratiosFor(topicId);
    return ratios.contains(_currentOptions.ratio)
        ? _currentOptions.ratio
        : ratios.first;
  }

  int? get duration {
    final choices = model?.capabilities.durations ?? const <int>[];
    final value = _currentOptions.duration;
    return choices.contains(value) ? value : choices.firstOrNull;
  }

  List<String> resolutionsFor(String? topicId) =>
      model?.capabilities.resolutionsFor(
        hasLastFrame:
            showsFrames(topicId) &&
            frame(topicId, MediaReferenceRole.lastFrame) != null,
      ) ??
      const [];

  String? resolutionFor(String? topicId) {
    final choices = resolutionsFor(topicId);
    final value = _currentOptions.resolution;
    return choices.contains(value) ? value : choices.firstOrNull;
  }

  void setMode(MediaMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void selectModel(MediaModelChoice choice) =>
      _updateOptions(modelKey: choice.key);
  void selectRatio(String value) => _updateOptions(ratio: value);
  void selectCount(int value) =>
      _updateOptions(count: value.clamp(1, MediaGenerationRunner.maxCount));
  void selectDuration(int value) => _updateOptions(duration: value);
  void selectResolution(String value) => _updateOptions(resolution: value);

  List<MediaReference> imageReferences(String? topicId) => draftFor(
    topicId,
  ).references.where((ref) => ref.role == MediaReferenceRole.image).toList();

  bool showsFrames(String? topicId) {
    final caps = model?.capabilities;
    return mode == MediaMode.video &&
        caps != null &&
        caps.frameRoles.isNotEmpty &&
        (caps.requiresFirstFrame || draftFor(topicId).videoFrames);
  }

  MediaReference? frame(String? topicId, MediaReferenceRole role) =>
      draftFor(topicId).references.where((ref) => ref.role == role).firstOrNull;

  void showFrames(String? topicId, bool value) {
    _drafts[topicId] = draftFor(topicId).copyWith(videoFrames: value);
    notifyListeners();
  }

  void setFrame(String? topicId, MediaReferenceRole role, String? path) {
    final draft = draftFor(topicId);
    _drafts[topicId] = draft.copyWith(
      videoFrames: true,
      references: [
        for (final ref in draft.references)
          if (ref.role != role) ref,
        if (path != null) MediaReference(path, role: role),
      ],
    );
    notifyListeners();
  }

  List<MediaReference> _effectiveReferences(String? topicId) {
    if (mode == MediaMode.image) return imageReferences(topicId);
    if (!showsFrames(topicId)) return const [];
    return [
      for (final role in model!.capabilities.frameRoles)
        if (frame(topicId, role) case final value?) value,
    ];
  }

  bool canSubmit(String? topicId) {
    final caps = model?.capabilities;
    if (caps == null ||
        submitting(topicId) ||
        _deletingTopics.contains(topicId)) {
      return false;
    }
    final refs = _effectiveReferences(topicId);
    if (mode == MediaMode.image) return refs.length <= caps.maxReferences;
    if (!showsFrames(topicId)) return !caps.requiresFirstFrame;
    return refs.any((ref) => ref.role == MediaReferenceRole.firstFrame);
  }

  void updatePrompt(String? topicId, String value) {
    _drafts[topicId] = draftFor(topicId).copyWith(prompt: value);
  }

  void setReferences(String? topicId, List<MediaReference> references) {
    final draft = draftFor(topicId);
    _drafts[topicId] = draft.copyWith(
      references: [
        for (final ref in draft.references)
          if (ref.role != MediaReferenceRole.image) ref,
        ...references,
      ],
    );
    notifyListeners();
  }

  Future<String?> submit(String? topicId) async {
    if (!canSubmit(topicId)) return null;
    final choice = model;
    final draft = draftFor(topicId);
    final prompt = draft.prompt.trim();
    if (choice == null || prompt.isEmpty) return null;
    final request = MediaRequest(
      modelId: choice.spec.id,
      mode: mode,
      prompt: prompt,
      count: count,
      aspectRatio: ratioFor(topicId),
      durationSec: duration,
      resolution: resolutionFor(topicId),
      references: _effectiveReferences(topicId),
    );
    final id = topicId ?? const Uuid().v4();
    final now = DateTime.now();
    final titleSource = _titleModel();
    final promptTitle = prompt.characters.take(20).toString();
    final naming = topicId == null && titleSource != null;
    if (naming) _namingTopics.add(id);
    _work.add(topicId);
    notifyListeners();
    try {
      await runner.enqueue(
        provider: choice.provider,
        request: request,
        topicId: id,
        newTopic: topicId == null
            ? GenerationTopicRowsCompanion.insert(
                id: id,
                title: promptTitle,
                titleSource: naming
                    ? GenerationTitleSource.auto
                    : GenerationTitleSource.prompt,
                createdAt: now,
                updatedAt: now,
              )
            : null,
      );
      if (identical(_drafts[topicId], draft)) _drafts.remove(topicId);
      if (topicId == null && titleSource != null) {
        unawaited(_nameTopic(id, prompt, promptTitle, titleSource));
      }
      return id;
    } catch (_) {
      _namingTopics.remove(id);
      rethrow;
    } finally {
      _work.remove(topicId);
      if (!_disposed) notifyListeners();
    }
  }

  ({ProviderConfig config, String model})? _titleModel() {
    final provider = settings.titleModelProvider;
    final id = settings.titleModelId;
    if (provider == null || id == null || !autoTitle) {
      return null;
    }
    final config = settings.getProviderConfig(provider);
    return config.enabled &&
            config.enabledModels.contains(id) &&
            ModelSpecResolver.instance.spec(config, id).type == ModelType.chat
        ? (config: config, model: id)
        : null;
  }

  Future<void> _nameTopic(
    String id,
    String prompt,
    String fallback,
    ({ProviderConfig config, String model}) source,
  ) async {
    final version = runner.repository.replacementVersion;
    var title = fallback;
    var origin = GenerationTitleSource.prompt;
    try {
      final result = await ChatApiService.generateText(
        config: source.config,
        modelId: source.model,
        prompt:
            'Give this creation request a short title in the language of the request. Return only the title.\n\n$prompt',
        skipImageParsing: true,
      ).timeout(const Duration(seconds: 40));
      final candidate = result.trim().split('\n').first.trim();
      if (candidate.isNotEmpty) {
        origin = GenerationTitleSource.auto;
        title = candidate.characters.take(40).toString();
      }
    } catch (_) {
      // The creation remains usable under the prompt-derived title.
    }
    if (_disposed) return;
    try {
      await AttachmentFileLock.synchronized(() async {
        if (runner.repository.canWrite &&
            runner.repository.replacementVersion == version) {
          await runner.repository.finishAutoTitle(id, title, origin);
        }
      });
    } catch (error, stack) {
      _storageError(error, stack);
    } finally {
      _namingTopics.remove(id);
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> renameTopic(String id, String name) async {
    final title = name.trim();
    if (title.isEmpty) return;
    await AttachmentFileLock.synchronized(
      () => runner.repository.renameTopic(
        id,
        title,
        GenerationTitleSource.manual,
      ),
    );
  }

  Future<void> deleteTopic(String id) async {
    if (!_deletingTopics.add(id)) return;
    try {
      final batches = await AttachmentFileLock.synchronized(
        () => runner.repository.batchesForTopic(id),
      );
      for (final batch in batches) {
        await runner.cancel(batch);
      }
      await AttachmentFileLock.synchronized(() async {
        await runner.repository.deleteTopic(id);
        for (final batch in batches) {
          await runner.files.deleteBatch(batch);
        }
      });
      _drafts.remove(id);
    } finally {
      _deletingTopics.remove(id);
    }
  }

  Future<void> deleteItem(GenerationItemRow item) =>
      AttachmentFileLock.synchronized(() async {
        await runner.repository.deleteItem(item.id);
        await runner.files.deleteItem(item);
      });

  Future<void> retry(GenerationBatchRow batch) async {
    if (_deletingTopics.contains(batch.topicId)) return;
    await runner.retry(batch.id, settings.getProviderConfig(batch.providerId));
  }

  GenerationBatchRow? batch(String id) =>
      _batches.where((batch) => batch.id == id).firstOrNull;

  void _settingsChanged() {
    _choices.clear();
    notifyListeners();
  }

  void _updateOptions({
    String? modelKey,
    String? ratio,
    int? count,
    int? duration,
    String? resolution,
  }) {
    _options[_mode] = (
      model: modelKey ?? model?.key,
      ratio: ratio ?? _currentOptions.ratio,
      count: count ?? _currentOptions.count,
      duration: duration ?? _currentOptions.duration,
      resolution: resolution ?? _currentOptions.resolution,
    );
    notifyListeners();
    unawaited(
      preferences
          .setString(
            BusinessKeyRegistry.creationComposerKey,
            jsonEncode({
              for (final entry in _options.entries)
                entry.key.name: {
                  'model': entry.value.model,
                  'ratio': entry.value.ratio,
                  'count': entry.value.count,
                  'duration': entry.value.duration,
                  'resolution': entry.value.resolution,
                },
            }),
          )
          .then<void>((_) {}, onError: _storageError),
    );
  }

  Map<MediaMode, _ComposerOptions> _readOptions() {
    final raw = preferences.getString(BusinessKeyRegistry.creationComposerKey);
    if (raw == null) return {};
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return {};
      return {
        for (final mode in MediaMode.values)
          if (data[mode.name] case final Map value)
            mode: (
              model: value['model'] is String ? value['model'] as String : null,
              ratio: value['ratio'] is String
                  ? value['ratio'] as String
                  : 'auto',
              count: value['count'] is int
                  ? (value['count'] as int).clamp(
                      1,
                      MediaGenerationRunner.maxCount,
                    )
                  : 1,
              duration: value['duration'] is int
                  ? value['duration'] as int
                  : null,
              resolution: value['resolution'] is String
                  ? value['resolution'] as String
                  : null,
            ),
      };
    } on FormatException {
      return {};
    }
  }

  static void _storageError(Object error, StackTrace stack) =>
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'creation history',
        ),
      );

  @override
  void dispose() {
    _disposed = true;
    settings.removeListener(_settingsChanged);
    unawaited(_topicsSubscription.cancel());
    unawaited(_batchesSubscription.cancel());
    unawaited(_itemsSubscription.cancel());
    super.dispose();
  }
}
