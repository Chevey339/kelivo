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
import '../../../core/services/media/media_adapter_resolver.dart';
import '../../../core/services/media/media_generation_runner.dart';
import '../../../core/services/media/media_models.dart';
import '../../../core/services/media/media_request.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../core/services/storage/attachment_file_lock.dart';

class CreationDraft {
  const CreationDraft({
    this.prompt = '',
    this.references = const [],
    this.videoFrames = false,
    this.platformImages = const {},
  });

  final String prompt;
  final List<MediaReference> references;
  final bool videoFrames;
  final Map<(String, String), String> platformImages;

  CreationDraft copyWith({
    String? prompt,
    List<MediaReference>? references,
    bool? videoFrames,
    Map<(String, String), String>? platformImages,
  }) => CreationDraft(
    prompt: prompt ?? this.prompt,
    references: references == null
        ? this.references
        : List.unmodifiable(references),
    videoFrames: videoFrames ?? this.videoFrames,
    platformImages: platformImages ?? this.platformImages,
  );
}

typedef _ComposerOptions = ({
  String? model,
  String ratio,
  int count,
  int? duration,
  String? resolution,
  Map<String, Map<String, dynamic>> parameters,
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
      _batchesById
        ..clear()
        ..addEntries(batches.map((batch) => MapEntry(batch.id, batch)));
      _batchesByTopic.clear();
      _batchesByMessage.clear();
      for (final batch in batches) {
        final id = batch.topicId;
        if (id != null) (_batchesByTopic[id] ??= []).add(batch);
        final message = batch.messageId;
        if (batch.source == GenerationSource.chat && message != null) {
          (_batchesByMessage[message] ??= []).add(batch);
        }
      }
      notifyListeners();
    }, onError: _storageError);
    _itemsSubscription = runner.repository.watchItems().listen((items) {
      _readyItems = items
          .where((item) => item.status == GenerationItemStatus.ready)
          .toList();
      _itemsById
        ..clear()
        ..addEntries(items.map((item) => MapEntry(item.id, item)));
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
  List<GenerationItemRow> _readyItems = const [];
  final _batchesById = <String, GenerationBatchRow>{};
  final _itemsById = <String, GenerationItemRow>{};
  final _batchesByTopic = <String, List<GenerationBatchRow>>{};
  final _batchesByMessage = <String, List<GenerationBatchRow>>{};
  final _itemsByBatch = <String, List<GenerationItemRow>>{};
  final _drafts = <String?, CreationDraft>{};
  final _options = <MediaMode, _ComposerOptions>{};
  final _choices = <MediaMode, List<MediaModelChoice>>{};
  final _work = <String?>{};
  final _deletingTopics = <String>{};
  final _deletingBatches = <String>{};
  final _repeatingBatches = <String>{};
  final _namingTopics = <String>{};
  final _lastSubmissionByTopic = <String, String>{};
  MediaMode _mode = MediaMode.image;
  bool _disposed = false;

  MediaMode get mode => _mode;
  List<GenerationTopicRow> get topics => _topics;
  GenerationTopicRow? topic(String id) =>
      _topics.where((row) => row.id == id).firstOrNull;
  List<GenerationBatchRow> batchesFor(String id) =>
      _batchesByTopic[id] ?? const [];
  List<GenerationBatchRow> chatBatchesFor(String messageId) =>
      _batchesByMessage[messageId] ?? const [];
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

  CreationTopicView get topicView {
    final key = preferences.getString(BusinessKeyRegistry.creationTopicViewKey);
    return CreationTopicView.values
            .where((value) => value.name == key)
            .firstOrNull ??
        CreationTopicView.coverAndTitle;
  }

  Future<void> setTopicView(CreationTopicView mode) async {
    await preferences.setString(
      BusinessKeyRegistry.creationTopicViewKey,
      mode.name,
    );
    if (!_disposed) notifyListeners();
  }

  Future<void> setAutoTitle(bool value) async {
    await preferences.setBool(BusinessKeyRegistry.creationAutoTitleKey, value);
    if (!_disposed) notifyListeners();
  }

  String? lastSubmission(String? topicId) => _lastSubmissionByTopic[topicId];

  void _submitted(String id, MediaGenerationTicket ticket) {
    _lastSubmissionByTopic[id] = ticket.batchId;
    if (!_disposed) notifyListeners();
  }

  int get galleryCount => _readyItems.length;
  GenerationItemRow? item(String id) => _itemsById[id];

  List<GenerationItemRow> galleryItems(
    CreationGalleryFilter filter,
    String query, {
    String? Function(String conversationId)? conversationTitle,
  }) {
    final term = query.trim().toLowerCase();
    return _readyItems.where((item) {
      final matches = switch (filter) {
        CreationGalleryFilter.all => true,
        CreationGalleryFilter.images => item.mode == MediaMode.image,
        CreationGalleryFilter.videos => item.mode == MediaMode.video,
        CreationGalleryFilter.favorites => item.favorite,
      };
      if (!matches) return false;
      if (term.isEmpty) return true;
      final parent = batch(item.batchId);
      if (parent == null) return false;
      final title = parent.topicId == null
          ? (parent.conversationId == null
                ? null
                : conversationTitle?.call(parent.conversationId!))
          : topic(parent.topicId!)?.title;
      return parent.prompt.toLowerCase().contains(term) ||
          (title?.toLowerCase().contains(term) ?? false);
    }).toList();
  }

  List<GenerationItemRow?> coverCells(String topicId) => [
    for (final batch in batchesFor(topicId).reversed) ...[
      if (batch.status.isActive) null,
      ...itemsFor(
        batch.id,
      ).where((item) => item.status == GenerationItemStatus.ready),
    ],
  ];

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

  List<MediaModelChoice> get models => modelsFor(_mode);

  List<MediaModelChoice> modelsFor(MediaMode mode) =>
      _choices.putIfAbsent(mode, () {
        final keys = {
          ...settings.providersOrder,
          ...settings.providerConfigs.keys,
        };
        return [
          for (final id in keys)
            ..._modelsForProvider(
              settings.getProviderConfig(id, defaultName: id),
              mode,
            ),
        ];
      });

  Iterable<MediaModelChoice> _modelsForProvider(
    ProviderConfig provider,
    MediaMode mode,
  ) sync* {
    for (final id in provider.enabledModels) {
      if (resolveMediaModel(provider, id, mode, resolver: runner.resolver)
          case final choice?) {
        yield choice;
      }
    }
  }

  _ComposerOptions get _currentOptions =>
      _options[_mode] ??
      (
        model: null,
        ratio: 'auto',
        count: 1,
        duration: null,
        resolution: null,
        parameters: const {},
      );
  final _selectedModels = <MediaMode, String>{};

  MediaModelChoice? get model {
    final slot = mode == MediaMode.image
        ? CreationModelSlot.image
        : CreationModelSlot.video;
    for (final key in [
      _selectedModels[mode],
      settings.creationModelKey(slot),
      _currentOptions.model,
    ]) {
      if (key == null) continue;
      final choice = models.where((choice) => choice.key == key).firstOrNull;
      if (choice != null) return choice;
    }
    return models.firstOrNull;
  }

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
        : ratios.firstOrNull ?? 'auto';
  }

  int? get duration {
    final choices = model?.capabilities.durations ?? const <int>[];
    final value = _currentOptions.duration;
    return choices.contains(value) ? value : choices.firstOrNull;
  }

  List<String> resolutionsFor(String? topicId) {
    final caps = model?.capabilities;
    if (caps == null) return const [];
    final candidates = caps.resolutionsFor(
      hasLastFrame:
          showsFrames(topicId) &&
          frame(topicId, MediaReferenceRole.lastFrame) != null,
    );
    return candidates
        .where((value) => caps.ratiosFor(value).isNotEmpty)
        .toList();
  }

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

  void selectModel(MediaModelChoice choice) {
    _selectedModels[mode] = choice.key;
    _updateOptions(modelKey: choice.key);
  }

  void selectRatio(String value) => _updateOptions(ratio: value);
  void selectCount(int value) =>
      _updateOptions(count: value.clamp(1, MediaGenerationRunner.maxCount));
  void selectDuration(int value) => _updateOptions(duration: value);
  void selectResolution(String value) => _updateOptions(resolution: value);

  Map<String, dynamic> get parameters =>
      _currentOptions.parameters[model?.key] ?? const {};

  void setParameter(String field, Object? value) {
    final key = model?.key;
    if (key == null) return;
    final update = {...parameters};
    if (value == null || value == '') {
      update.remove(field);
    } else {
      update[field] = value;
    }
    _updateOptions(parameters: {..._currentOptions.parameters, key: update});
  }

  String? platformImage(String? topicId, String field) {
    final key = model?.key;
    return key == null ? null : draftFor(topicId).platformImages[(key, field)];
  }

  void setPlatformImage(
    String? topicId,
    String modelKey,
    String field,
    String? path,
  ) {
    final draft = draftFor(topicId);
    final images = {...draft.platformImages};
    if (path == null) {
      images.remove((modelKey, field));
    } else {
      images[(modelKey, field)] = path;
    }
    _drafts[topicId] = draft.copyWith(platformImages: images);
    notifyListeners();
  }

  bool hasAdvancedOptions(String? topicId) =>
      parameters.isNotEmpty ||
      draftFor(
        topicId,
      ).platformImages.keys.any((entry) => entry.$1 == model?.key);

  Map<String, dynamic>? get extraParameters {
    final raw = parameters['extra'];
    if (raw is! String || raw.trim().isEmpty) return const {};
    try {
      final parsed = jsonDecode(raw);
      return parsed is Map<String, dynamic> ? parsed : null;
    } on FormatException {
      return null;
    }
  }

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

  List<MediaReference> _effectiveReferences(
    String? topicId,
    MediaCapabilities caps,
  ) => [
    if (mode == MediaMode.image && caps.maxReferences > 0)
      ...imageReferences(topicId),
    if (mode == MediaMode.video && showsFrames(topicId))
      for (final role in caps.frameRoles)
        if (frame(topicId, role) case final value?) value,
    for (final option in caps.platformOptions)
      if (option.type == MediaParameterType.image)
        if (platformImage(topicId, option.key) case final path?)
          MediaReference(
            path,
            role: MediaReferenceRole.platform,
            parameterKey: option.key,
          ),
  ];

  bool canSubmit(String? topicId) {
    final selected = model;
    final caps = selected?.capabilities;
    if (selected == null ||
        caps == null ||
        submitting(topicId) ||
        _deletingTopics.contains(topicId) ||
        ratiosFor(topicId).isEmpty ||
        extraParameters == null ||
        (caps.supportsSeed &&
            parameters['seed'] != null &&
            int.tryParse(parameters['seed'].toString()) == null)) {
      return false;
    }
    final defaults = MediaAdapterResolver.overrides(
      selected.provider,
      selected.spec.id,
    ).extra;
    if (caps.platformOptions.any(
      (field) =>
          field.type == MediaParameterType.image &&
          field.required &&
          platformImage(topicId, field.key) == null &&
          extraParameters?[field.key] is! String &&
          defaults[field.key] is! String,
    )) {
      return false;
    }
    final refs = _effectiveReferences(
      topicId,
      caps,
    ).where((ref) => ref.role != MediaReferenceRole.platform);
    if (mode == MediaMode.image) {
      return refs.length <= caps.maxReferences &&
          (refs.isNotEmpty || !caps.requiresReference);
    }
    if (!showsFrames(topicId)) return !caps.requiresFirstFrame;
    return refs.any((ref) => ref.role == MediaReferenceRole.firstFrame);
  }

  int addReferencePaths(
    String? topicId,
    List<String> paths, {
    MediaReferenceRole? frameRole,
  }) {
    final caps = model?.capabilities;
    if (caps == null || paths.isEmpty) return 0;
    if (mode == MediaMode.video) {
      final role = frameRole ?? MediaReferenceRole.firstFrame;
      if (!caps.frameRoles.contains(role)) return 0;
      setFrame(topicId, role, paths.first);
      return 1;
    }
    final existing = imageReferences(topicId);
    final seen = existing.map((ref) => ref.path).toSet();
    final choices = paths
        .where(seen.add)
        .take((caps.maxReferences - existing.length).clamp(0, 16))
        .toList();
    if (choices.isEmpty) return 0;
    setReferences(topicId, [...existing, ...choices.map(MediaReference.new)]);
    return choices.length;
  }

  void suggestPrompt(String? topicId, String prompt) {
    updatePrompt(topicId, prompt);
    notifyListeners();
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
    final caps = choice.capabilities;
    final options = parameters;
    final request = MediaRequest(
      modelId: choice.spec.id,
      mode: mode,
      prompt: prompt,
      negativePrompt:
          caps.supportsNegativePrompt &&
              options['negativePrompt'] is String &&
              (options['negativePrompt'] as String).trim().isNotEmpty
          ? (options['negativePrompt'] as String).trim()
          : null,
      count: count,
      aspectRatio: ratioFor(topicId),
      durationSec: duration,
      resolution: resolutionFor(topicId),
      references: _effectiveReferences(topicId, caps),
      parameters: {
        if (caps.sizes.contains(options['size'])) 'size': options['size'],
        if (caps.qualities.contains(options['quality']))
          'quality': options['quality'],
        if (caps.formats.contains(options['format']))
          'format': options['format'],
        if (caps.supportsTransparent && options['background'] is String)
          'background': options['background'],
        if (caps.supportsSeed && options['seed'] != null)
          'seed': int.parse(options['seed'].toString()),
        for (final field in caps.platformOptions)
          if (field.type != MediaParameterType.image &&
              options[field.key] != null)
            field.key: options[field.key],
        if (extraParameters case final extra? when extra.isNotEmpty)
          'extra': extra,
      },
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
      final ticket = await runner.enqueue(
        provider: choice.provider,
        request: request,
        topicId: id,
        canEnqueue: () => !_deletingTopics.contains(id),
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
      _submitted(id, ticket);
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
      _lastSubmissionByTopic.remove(id);
    } finally {
      _deletingTopics.remove(id);
    }
  }

  Future<void> deleteItem(GenerationItemRow item) =>
      AttachmentFileLock.synchronized(() async {
        await runner.repository.deleteItem(item.id);
        await runner.files.deleteItem(item);
      });

  Future<void> setFavorite(String itemId, bool value) =>
      AttachmentFileLock.synchronized(
        () => runner.repository.setFavorite(itemId, value),
      );

  Future<void> deleteBatch(GenerationBatchRow batch) async {
    if (_deletingTopics.contains(batch.topicId) ||
        !_deletingBatches.add(batch.id)) {
      return;
    }
    try {
      // A retry may already be writing its queued state under the file lock.
      // Let it finish registration before cancelling the corresponding job.
      await AttachmentFileLock.synchronized(() async {});
      await runner.cancel(batch.id);
      await AttachmentFileLock.synchronized(() async {
        await runner.repository.deleteBatch(batch.id);
        await runner.files.deleteBatch(batch.id);
      });
    } finally {
      _deletingBatches.remove(batch.id);
    }
  }

  Future<MediaGenerationTicket?> repeat(GenerationBatchRow row) async {
    final topicId = row.topicId;
    if (topicId == null ||
        row.status.isActive ||
        _deletingTopics.contains(topicId) ||
        _deletingBatches.contains(row.id) ||
        !_repeatingBatches.add(row.id)) {
      return null;
    }
    try {
      final current = await runner.repository.batch(row.id);
      if (current == null ||
          _deletingBatches.contains(row.id) ||
          _deletingTopics.contains(topicId)) {
        return null;
      }
      final ticket = await runner.enqueue(
        provider: settings.getProviderConfig(row.providerId),
        request: MediaRequest.fromBatch(current),
        topicId: topicId,
        source: current.source == GenerationSource.edit
            ? GenerationSource.edit
            : GenerationSource.workbench,
        parentItemId: current.parentItemId,
        applyModelExtra: false,
        canEnqueue: () =>
            !_deletingTopics.contains(topicId) &&
            !_deletingBatches.contains(row.id),
      );
      _submitted(topicId, ticket);
      return ticket;
    } finally {
      _repeatingBatches.remove(row.id);
    }
  }

  MediaModelChoice? editingModel(GenerationItemRow item) {
    if (item.mode != MediaMode.image || batch(item.batchId)?.topicId == null) {
      return null;
    }
    final choices = modelsFor(MediaMode.image).where(
      (choice) =>
          choice.capabilities.maxReferences > 0 &&
          !choice.capabilities.platformOptions.any((field) => field.required),
    );
    final current = _options[MediaMode.image]?.model;
    final original = batch(item.batchId);
    return choices.where((choice) => choice.key == current).firstOrNull ??
        choices
            .where(
              (choice) =>
                  choice.provider.id == original?.providerId &&
                  choice.spec.id == original?.modelId,
            )
            .firstOrNull ??
        choices.firstOrNull;
  }

  Future<MediaGenerationTicket?> editItem(
    GenerationItemRow item,
    MediaModelChoice choice, {
    required String prompt,
    required String ratio,
  }) async {
    final topicId = batch(item.batchId)?.topicId;
    if (topicId == null ||
        _deletingTopics.contains(topicId) ||
        _deletingBatches.contains(item.batchId) ||
        prompt.trim().isEmpty) {
      return null;
    }
    final ticket = await runner.enqueue(
      provider: settings.getProviderConfig(choice.provider.id),
      request: MediaRequest(
        modelId: choice.spec.id,
        mode: MediaMode.image,
        prompt: prompt.trim(),
        aspectRatio: ratio,
        references: [MediaReference(item.path)],
      ),
      topicId: topicId,
      source: GenerationSource.edit,
      parentItemId: item.id,
      canEnqueue: () =>
          !_deletingTopics.contains(topicId) &&
          !_deletingBatches.contains(item.batchId),
    );
    _submitted(topicId, ticket);
    return ticket;
  }

  Future<void> retry(GenerationBatchRow batch) async {
    if (_deletingTopics.contains(batch.topicId) ||
        _deletingBatches.contains(batch.id)) {
      return;
    }
    await runner.retry(
      batch.id,
      settings.getProviderConfig(batch.providerId),
      canRetry: () =>
          !_deletingTopics.contains(batch.topicId) &&
          !_deletingBatches.contains(batch.id),
    );
  }

  GenerationBatchRow? batch(String id) => _batchesById[id];

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
    Map<String, Map<String, dynamic>>? parameters,
  }) {
    _options[_mode] = (
      model: modelKey ?? model?.key,
      ratio: ratio ?? _currentOptions.ratio,
      count: count ?? _currentOptions.count,
      duration: duration ?? _currentOptions.duration,
      resolution: resolution ?? _currentOptions.resolution,
      parameters: parameters ?? _currentOptions.parameters,
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
                  if (entry.value.parameters.isNotEmpty)
                    'parameters': entry.value.parameters,
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
              parameters: {
                if (value['parameters'] case final Map<String, dynamic> sets)
                  for (final entry in sets.entries)
                    if (entry.value case final Map<String, dynamic> values)
                      entry.key: values,
              },
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
