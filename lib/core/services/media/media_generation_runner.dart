import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../database/media_repository.dart';
import '../../models/media_creation.dart';
import '../../providers/settings_provider.dart';
import '../api/chat_api_helpers.dart';
import '../auth/provider_oauth_service.dart';
import '../mobile_background.dart';
import '../network/provider_http_client.dart';
import '../storage/attachment_file_lock.dart';
import 'media_adapter.dart';
import 'media_adapter_resolver.dart';
import 'media_file_store.dart';
import 'media_request.dart';

class MediaGenerationTicket {
  const MediaGenerationTicket(this.batchId, this.completed);

  final String batchId;
  final Future<GenerationStatus> completed;
}

typedef MediaRunProgress = ({double? fraction, String? preview});
typedef MediaHttpClientFactory =
    http.Client Function(ProviderConfig, CancelToken);

class MediaGenerationRunner extends ChangeNotifier {
  MediaGenerationRunner({
    required this.repository,
    required this.files,
    this.resolver = const MediaAdapterResolver(),
    MediaHttpClientFactory? clientFactory,
    Future<void> Function(Duration)? delay,
    MobileBackgroundCoordinator? background,
  }) : _client = clientFactory ?? _defaultClient,
       _delay = delay ?? Future<void>.delayed,
       _background = background ?? MobileBackgroundCoordinator.instance;

  final MediaRepository repository;
  final MediaFileStore files;
  final MediaAdapterResolver resolver;
  final MediaHttpClientFactory _client;
  final Future<void> Function(Duration) _delay;
  final MobileBackgroundCoordinator _background;
  final _queued = <_MediaJob>[];
  final _active = <String, _MediaJob>{};
  final _progress = <String, MediaRunProgress>{};
  final _retrying = <String>{};
  bool _disposed = false;
  bool _closing = false;
  Future<void>? _shutdownTask;

  static const maxActive = 4;
  static const maxActivePerProvider = 2;
  static const maxCount = 16;
  static const _uuid = Uuid();
  late final Future<void> initialized = repository.markInterrupted();

  MediaRunProgress? progressFor(String id) => _progress[id];

  int queueAhead(String id) {
    final index = _queued.indexWhere((job) => job.id == id);
    return index < 0 ? 0 : index + _active.length;
  }

  static http.Client _defaultClient(
    ProviderConfig provider,
    CancelToken token,
  ) => providerHttpClient(
    provider,
    cancelToken: token,
    timeout: const Duration(minutes: 3),
    logRequests: false,
  );

  MediaCapabilities? capabilities(
    ProviderConfig provider,
    MediaMode mode,
    String id,
  ) => resolver.capabilities(provider, mode, id);

  MediaCapabilities _validate(ProviderConfig provider, MediaRequest request) {
    final caps = capabilities(provider, request.mode, request.modelId);
    if (caps == null ||
        !provider.enabled ||
        !provider.enabledModels.contains(request.modelId) ||
        request.count < 1 ||
        request.count > maxCount ||
        request.prompt.trim().isEmpty ||
        (!caps.ratiosFor(request.resolution).contains(request.aspectRatio) &&
            !(request.mode == MediaMode.video &&
                request.aspectRatio == 'auto' &&
                caps.framesUseAutomaticRatio &&
                request.frame(MediaReferenceRole.firstFrame) != null)) ||
        request.inputImages.length > caps.maxReferences ||
        caps.requiresReference && request.inputImages.isEmpty ||
        (caps.maxCombinedInputsAndOutputs ?? 32) <=
            request.inputImages.length) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Invalid generation request',
      );
    }
    final platformImages = {
      for (final field in caps.platformOptions)
        if (field.type == MediaParameterType.image) field.key: field,
    };
    final suppliedImages = request.references
        .where((ref) => ref.role == MediaReferenceRole.platform)
        .map((ref) => ref.parameterKey)
        .toList();
    final modelExtra = MediaAdapterResolver.overrides(
      provider,
      request.modelId,
    ).extra;
    final requestExtra = request.parameters['extra'];
    if (suppliedImages.any((key) => !platformImages.containsKey(key)) ||
        suppliedImages.length != suppliedImages.toSet().length ||
        platformImages.values.any(
          (field) =>
              field.required &&
              !suppliedImages.contains(field.key) &&
              !(requestExtra is Map && requestExtra[field.key] is String) &&
              modelExtra[field.key] is! String,
        )) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Invalid platform image input',
      );
    }
    if (request.mode == MediaMode.video && !_validVideoRequest(request, caps)) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Invalid video settings or frame selection',
      );
    }
    return caps;
  }

  static bool _validVideoRequest(MediaRequest request, MediaCapabilities caps) {
    final roles = request.inputImages
        .map((reference) => reference.role)
        .toSet();
    final first = roles.contains(MediaReferenceRole.firstFrame);
    final last = roles.contains(MediaReferenceRole.lastFrame);
    return request.count == 1 &&
        (request.durationSec == null ||
            caps.durations.contains(request.durationSec)) &&
        (request.resolution == null ||
            caps
                .resolutionsFor(hasLastFrame: last)
                .contains(request.resolution)) &&
        roles.length == request.inputImages.length &&
        roles.every(caps.frameRoles.contains) &&
        (first || !caps.requiresFirstFrame && !last);
  }

  Future<MediaGenerationTicket> enqueue({
    required ProviderConfig provider,
    required MediaRequest request,
    String? topicId,
    GenerationTopicRowsCompanion? newTopic,
    GenerationSource source = GenerationSource.workbench,
    String? parentItemId,
    String? conversationId,
    String? messageId,
  }) async {
    await initialized;
    _requireOpen();
    final caps = _validate(provider, request);
    final extra = request.parameters['extra'];
    request = request.copyWith(
      parameters: {
        ...request.parameters,
        'extra': MediaAdapterResolver.overrides(
          provider,
          request.modelId,
        ).requestExtra(extra is Map<String, dynamic> ? extra : const {}),
      },
    );
    final id = _uuid.v4();
    final now = DateTime.now();
    return AttachmentFileLock.synchronized(() async {
      try {
        final refs = await files.snapshotReferences(id, request.references);
        request = request.copyWith(references: refs);
        _requireOpen();
        await repository.enqueue(
          GenerationBatchRowsCompanion.insert(
            id: id,
            topicId: Value(newTopic?.id.value ?? topicId),
            providerId: provider.id,
            modelId: request.modelId,
            mode: request.mode,
            prompt: request.prompt,
            negativePrompt: Value(request.negativePrompt),
            paramsJson: jsonEncode(request.storedParameters),
            referencesJson: jsonEncode([for (final ref in refs) ref.toJson()]),
            status: GenerationStatus.queued,
            source: source,
            parentItemId: Value(parentItemId),
            conversationId: Value(conversationId),
            messageId: Value(messageId),
            createdAt: now,
          ),
          topic: newTopic,
        );
      } catch (_) {
        await files.deleteBatch(id);
        rethrow;
      }
      final job = _MediaJob(
        id: id,
        provider: provider,
        request: request,
        capabilities: caps,
        replacementVersion: repository.replacementVersion,
      );
      _queued.add(job);
      _drain();
      return MediaGenerationTicket(id, job.result.future);
    });
  }

  Future<MediaGenerationTicket?> retry(
    String id,
    ProviderConfig provider,
  ) async {
    await initialized;
    _requireOpen();
    if (!_retrying.add(id)) return null;
    try {
      return await AttachmentFileLock.synchronized(() async {
        if (_active.containsKey(id) || _queued.any((job) => job.id == id)) {
          return null;
        }
        final batch = await repository.batch(id);
        if (batch == null ||
            batch.providerId != provider.id ||
            !{
              GenerationStatus.failed,
              GenerationStatus.partial,
              GenerationStatus.interrupted,
              GenerationStatus.cancelled,
            }.contains(batch.status)) {
          return null;
        }
        final params = jsonDecode(batch.paramsJson) as Map<String, dynamic>;
        final request = MediaRequest(
          modelId: batch.modelId,
          mode: batch.mode,
          prompt: batch.prompt,
          negativePrompt: batch.negativePrompt,
          count: params.remove('count') as int? ?? 1,
          aspectRatio: params.remove('aspectRatio') as String? ?? 'auto',
          durationSec: params.remove('durationSec') as int?,
          resolution: params.remove('resolution') as String?,
          parameters: params,
          references: [
            for (final row in jsonDecode(batch.referencesJson) as List)
              MediaReference.fromJson((row as Map).cast<String, dynamic>()),
          ],
        );
        final caps = _validate(provider, request);
        _requireOpen();
        await repository.updateBatch(
          id,
          const GenerationBatchRowsCompanion(
            status: Value(GenerationStatus.queued),
            startedAt: Value(null),
            finishedAt: Value(null),
            errorJson: Value(null),
          ),
        );
        final job = _MediaJob(
          id: id,
          provider: provider,
          request: request,
          capabilities: caps,
          replacementVersion: repository.replacementVersion,
        );
        _queued.add(job);
        _drain();
        return MediaGenerationTicket(id, job.result.future);
      });
    } finally {
      _retrying.remove(id);
    }
  }

  Future<void> cancel(String id) async {
    final queued = _queued.indexWhere((job) => job.id == id);
    if (queued != -1) {
      final job = _queued.removeAt(queued);
      job.token.cancel();
      await _finish(job, GenerationStatus.cancelled);
      return;
    }
    final active = _active[id];
    if (active == null) return;
    active.token.cancel();
    await active.result.future;
  }

  void _drain() {
    if (_closing) return;
    while (_active.length < maxActive) {
      final index = _queued.indexWhere(
        (job) =>
            _active.values
                .where((active) => active.provider.id == job.provider.id)
                .length <
            maxActivePerProvider,
      );
      if (index == -1) return;
      final job = _queued.removeAt(index);
      _active[job.id] = job;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_MediaJob job) async {
    var saved = 0;
    MediaFailure? failure;
    try {
      final existing = await repository.itemsForBatch(job.id);
      saved = existing.length;
      await files.validateReferences(job.request.references);
      var ordinal = existing.isEmpty ? 0 : existing.last.ordinal + 1;
      await _updateActiveBatch(
        job,
        GenerationBatchRowsCompanion(
          status: const Value(GenerationStatus.running),
          startedAt: Value(DateTime.now()),
        ),
      );
      if (job.request.mode == MediaMode.video) {
        await _background.start(
          id: job.backgroundId,
          conversationId: '',
          title: job.provider.name,
          keepAliveOnly: true,
          cancel: () => cancel(job.id),
        );
        _background.update(
          job.backgroundId,
          phase: BackgroundTaskPhase.generating,
        );
      }
      final raw = _client(job.provider, job.token);
      try {
        final adapter = resolver.resolve(
          job.provider,
          job.request.mode,
          modelId: job.request.modelId,
        )!;
        final auth = ProviderOAuthService.instance.authenticatedClient(
          raw,
          job.provider,
          cancelToken: job.token,
        );
        final apiKey = job.provider.isOAuth
            ? ''
            : apiKeyForRequest(job.provider, job.request.modelId);
        for (var attempt = saved; attempt < job.request.count;) {
          _checkCancelled(job);
          final maxCombined = job.capabilities.maxCombinedInputsAndOutputs;
          var requestCap = job.capabilities.maxPerRequest;
          if (maxCombined != null) {
            requestCap = math.min(
              requestCap,
              maxCombined - job.request.inputImages.length,
            );
          }
          final count = math.min(requestCap, job.request.count - attempt);
          final request = job.request.copyWith(count: count);
          final context = MediaContext(
            provider: job.provider,
            client: auth,
            apiKey: apiKey,
            cancelToken: job.token,
            requestId: _uuid.v4(),
            delay: _delay,
          );
          final results = await _requestWithRetry(
            job,
            adapter,
            context,
            request,
            completed: attempt,
          );
          await _updateActiveBatch(
            job,
            const GenerationBatchRowsCompanion(
              status: Value(GenerationStatus.downloading),
            ),
          );
          for (final result in results.take(count)) {
            try {
              _checkCancelled(job);
              await files.store(
                batchId: job.id,
                ordinal: ordinal,
                mode: request.mode,
                result: result,
                downloadClient: raw,
                publish: (item) async {
                  _checkCancelled(job);
                  await repository.addItem(item);
                },
              );
              saved++;
              ordinal++;
            } catch (_) {
              _checkCancelled(job);
              failure = const MediaFailure(
                MediaFailureKind.download,
                'Could not save a generation result',
              );
            }
          }
          attempt += count;
          if (attempt < job.request.count) {
            await _updateActiveBatch(
              job,
              const GenerationBatchRowsCompanion(
                status: Value(GenerationStatus.running),
              ),
            );
          }
        }
      } finally {
        raw.close();
      }
      _checkCancelled(job);
      final success = saved >= job.request.count;
      await _finish(
        job,
        success
            ? GenerationStatus.succeeded
            : saved > 0
            ? GenerationStatus.partial
            : GenerationStatus.failed,
        success
            ? null
            : failure ??
                  const MediaFailure(
                    MediaFailureKind.invalidResponse,
                    'Incomplete output',
                  ),
      );
    } catch (error) {
      final status = _closing || _background.wasInterrupted(job.backgroundId)
          ? GenerationStatus.interrupted
          : job.token.isCancelled
          ? GenerationStatus.cancelled
          : saved > 0
          ? GenerationStatus.partial
          : GenerationStatus.failed;
      await _finish(
        job,
        status,
        job.token.isCancelled ? null : classifyMediaFailure(error),
      );
    } finally {
      if (job.remoteTask case MediaTaskAccepted(
        cancelUrl: final url?,
        :final cancelMethod,
        :final cancelHeaders,
      ) when job.token.isCancelled) {
        unawaited(
          _cancelRemote(job.provider, url, cancelMethod, cancelHeaders),
        );
      }
      _active.remove(job.id);
      _progress.remove(job.id);
      if (!_disposed) notifyListeners();
      _drain();
    }
  }

  Future<List<MediaResult>> _requestWithRetry(
    _MediaJob job,
    MediaAdapter adapter,
    MediaContext context,
    MediaRequest request, {
    required int completed,
  }) async {
    for (var retry = 0; ; retry++) {
      var accepted = false;
      try {
        _checkCancelled(job);
        List<MediaResult>? results;
        await for (final event in adapter.generate(context, request)) {
          if (event is MediaTaskAccepted) {
            job.remoteTask = event;
            accepted = true;
          }
          _checkCancelled(job);
          final previous = _progress[job.id];
          switch (event) {
            case MediaOutput(results: final values):
              results = values;
            case MediaTaskAccepted():
              break;
            case MediaProgress(:final fraction):
              _progress[job.id] = (
                fraction:
                    (completed + fraction.clamp(0, 1) * request.count) /
                    job.request.count,
                preview: previous?.preview,
              );
            case MediaPreview(:final base64):
              _progress[job.id] = (
                fraction: previous?.fraction,
                preview: base64,
              );
          }
          if (!_disposed) notifyListeners();
        }
        if (results == null || results.isEmpty) {
          throw const MediaFailure(
            MediaFailureKind.invalidResponse,
            'Provider returned no media',
          );
        }
        return results;
      } catch (error) {
        _checkCancelled(job);
        final failure = classifyMediaFailure(error);
        if (accepted || !failure.retryable || retry == 3) throw failure;
        final interval = Duration(seconds: 1 << retry);
        final retryAfter = failure.retryAfter;
        await Future.any<void>([
          _delay(
            retryAfter != null && retryAfter > interval ? retryAfter : interval,
          ),
          job.token.whenCancel.then<void>((error) => throw error),
        ]);
      }
    }
  }

  Future<void> _cancelRemote(
    ProviderConfig provider,
    Uri url,
    String method,
    Map<String, String> headers,
  ) async {
    final token = CancelToken();
    http.Client? client;
    try {
      client = _client(provider, token);
      final request = http.Request(method, url)
        ..followRedirects = false
        ..headers.addAll(headers);
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 5));
      await response.stream.listen(null).cancel();
    } catch (_) {
      // A provider can accept cancellation only while its task is queued.
    } finally {
      token.cancel();
      client?.close();
    }
  }

  void _checkCancelled(_MediaJob job) {
    if (job.replacementVersion != repository.replacementVersion) {
      throw StateError('Generation history was replaced');
    }
    final error = job.token.cancelError;
    if (error != null) throw error;
  }

  Future<void> _updateActiveBatch(
    _MediaJob job,
    GenerationBatchRowsCompanion values,
  ) => AttachmentFileLock.synchronized(() async {
    _checkCancelled(job);
    await repository.updateBatch(job.id, values);
  });

  void _requireOpen() {
    if (_closing || !repository.canWrite) {
      throw StateError('Media generation is unavailable');
    }
  }

  Future<void> _finish(
    _MediaJob job,
    GenerationStatus status, [
    MediaFailure? error,
  ]) async {
    try {
      status = await AttachmentFileLock.synchronized(() async {
        if (!repository.canWrite ||
            job.replacementVersion != repository.replacementVersion) {
          return GenerationStatus.interrupted;
        }
        await repository.updateBatch(
          job.id,
          GenerationBatchRowsCompanion(
            status: Value(status),
            finishedAt: Value(DateTime.now()),
            errorJson: Value(error == null ? null : jsonEncode(error.toJson())),
          ),
        );
        return status;
      });
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'media generation storage',
        ),
      );
      status = GenerationStatus.failed;
    }
    if (job.request.mode == MediaMode.video) {
      final outcome = switch (status) {
        GenerationStatus.succeeded ||
        GenerationStatus.partial => BackgroundTaskOutcome.completed,
        GenerationStatus.cancelled => BackgroundTaskOutcome.cancelled,
        GenerationStatus.interrupted => BackgroundTaskOutcome.interrupted,
        _ => BackgroundTaskOutcome.failed,
      };
      await _background.finish(job.backgroundId, outcome);
    }
    job.result.complete(status);
  }

  Future<void> shutdown() => _shutdownTask ??= _shutdown();

  Future<void> _shutdown() async {
    _closing = true;
    final (active, queued) = await AttachmentFileLock.synchronized(() async {
      final queued = _queued.toList();
      _queued.clear();
      return (_active.values.toList(), queued);
    });
    for (final job in active) {
      job.token.cancel();
    }
    await Future.wait([
      for (final job in queued) _finish(job, GenerationStatus.interrupted),
      for (final job in active) job.result.future.then<void>((_) {}),
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(shutdown());
    super.dispose();
  }
}

class _MediaJob {
  _MediaJob({
    required this.id,
    required this.provider,
    required this.request,
    required this.capabilities,
    required this.replacementVersion,
  });

  final String id;
  final ProviderConfig provider;
  final MediaRequest request;
  final MediaCapabilities capabilities;
  final int replacementVersion;
  final result = Completer<GenerationStatus>();
  final token = CancelToken();
  MediaTaskAccepted? remoteTask;
  String get backgroundId => 'creation-$id';
}
