import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';

enum SherpaModelArchitecture { paraformer, senseVoice, streamingZipformer }

/// A downloadable model published by sherpa-onnx's official `asr-models`
/// GitHub release.
final class SherpaModelDefinition {
  const SherpaModelDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.architecture,
    required this.archiveUri,
    required this.downloadBytes,
    required this.archiveRoot,
    required this.requiredFiles,
    this.modelFile,
    this.tokensFile = 'tokens.txt',
    this.encoderFile,
    this.decoderFile,
    this.joinerFile,
  });

  final String id;
  final String name;
  final String description;
  final SherpaModelArchitecture architecture;
  final Uri archiveUri;
  final int downloadBytes;
  final String archiveRoot;
  final List<String> requiredFiles;

  final String? modelFile;
  final String tokensFile;
  final String? encoderFile;
  final String? decoderFile;
  final String? joinerFile;
}

abstract final class SherpaModelCatalog {
  static final List<SherpaModelDefinition> models = List.unmodifiable([
    SherpaModelDefinition(
      id: 'paraformer-zh-small-2024-03-09',
      name: 'Paraformer 中文小模型',
      description: '中文优先，兼顾简单英文，下载约 78 MB',
      architecture: SherpaModelArchitecture.paraformer,
      archiveUri: Uri.parse(
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
        'sherpa-onnx-paraformer-zh-small-2024-03-09.tar.bz2',
      ),
      downloadBytes: 77920048,
      archiveRoot: 'sherpa-onnx-paraformer-zh-small-2024-03-09',
      requiredFiles: ['model.int8.onnx', 'tokens.txt'],
      modelFile: 'model.int8.onnx',
    ),
    SherpaModelDefinition(
      id: 'sense-voice-multilingual-int8-2025-09-09',
      name: 'SenseVoice int8 多语模型',
      description: '支持中文、英文、粤语、日语和韩语，下载约 166 MB',
      architecture: SherpaModelArchitecture.senseVoice,
      archiveUri: Uri.parse(
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
        'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09.tar.bz2',
      ),
      downloadBytes: 165783878,
      archiveRoot: 'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09',
      requiredFiles: ['model.int8.onnx', 'tokens.txt'],
      modelFile: 'model.int8.onnx',
    ),
    SherpaModelDefinition(
      id: 'zipformer-zh-en-mobile-2023-02-20',
      name: 'Zipformer 中英 Mobile',
      description: '中英双语流式识别，下载约 347 MB',
      architecture: SherpaModelArchitecture.streamingZipformer,
      archiveUri: Uri.parse(
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
        'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20-mobile'
        '.tar.bz2',
      ),
      downloadBytes: 346965352,
      archiveRoot:
          'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20-mobile',
      requiredFiles: [
        'encoder-epoch-99-avg-1.int8.onnx',
        'decoder-epoch-99-avg-1.onnx',
        'joiner-epoch-99-avg-1.int8.onnx',
        'tokens.txt',
      ],
      encoderFile: 'encoder-epoch-99-avg-1.int8.onnx',
      decoderFile: 'decoder-epoch-99-avg-1.onnx',
      joinerFile: 'joiner-epoch-99-avg-1.int8.onnx',
    ),
  ]);

  static SherpaModelDefinition? byId(String id) {
    for (final model in models) {
      if (model.id == id) return model;
    }
    return null;
  }
}

enum SherpaModelDownloadPhase { downloading, extracting, installing }

final class SherpaModelDownloadProgress {
  const SherpaModelDownloadProgress({
    required this.modelId,
    required this.phase,
    required this.receivedBytes,
    required this.totalBytes,
  });

  final String modelId;
  final SherpaModelDownloadPhase phase;
  final int receivedBytes;
  final int? totalBytes;

  /// Number of archive bytes received from the network so far.
  int get bytesReceived => receivedBytes;

  /// Download completion in the inclusive range 0...1.
  ///
  /// Returns null when neither the server nor the model catalog provides a
  /// usable total size.
  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0, 1).toDouble();
  }

  /// Whole-number download percentage suitable for a UI label.
  ///
  /// This intentionally rounds down so an in-flight download cannot display
  /// 100% merely because it is close to completion.
  int? get percent {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    if (receivedBytes <= 0) return 0;
    if (receivedBytes >= total) return 100;
    return (receivedBytes * 100) ~/ total;
  }

  int? get displayPercent => percent;

  /// Backwards-compatible alias used by the existing model progress bar.
  double? get fraction => progress;
}

typedef SherpaModelProgressCallback =
    void Function(SherpaModelDownloadProgress progress);

enum SherpaModelInstallState { notInstalled, downloading, installed, failed }

final class SherpaModelInstallStatus {
  const SherpaModelInstallStatus({
    required this.model,
    required this.state,
    this.progress,
    this.error,
  });

  final SherpaModelDefinition model;
  final SherpaModelInstallState state;
  final SherpaModelDownloadProgress? progress;
  final String? error;

  bool get isInstalled => state == SherpaModelInstallState.installed;
}

final class SherpaDownloadCancellationToken {
  final Completer<void> _cancelledCompleter = Completer<void>();

  bool get isCancelled => _cancelledCompleter.isCompleted;
  Future<void> get whenCancelled => _cancelledCompleter.future;

  void cancel() {
    if (!_cancelledCompleter.isCompleted) _cancelledCompleter.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const SherpaDownloadCancelledException();
  }
}

final class SherpaDownloadCancelledException implements Exception {
  const SherpaDownloadCancelledException();

  @override
  String toString() => 'Sherpa model download was cancelled';
}

/// Downloads, validates, and installs sherpa-onnx models outside the app
/// bundle. A model only becomes visible at `<app data>/asr_models/<id>` after
/// every required inference file has been verified.
final class SherpaModelManager {
  SherpaModelManager({
    http.Client? httpClient,
    Directory? modelsRoot,
    List<SherpaModelDefinition>? catalog,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _injectedModelsRoot = modelsRoot,
       catalog = List.unmodifiable(catalog ?? SherpaModelCatalog.models);

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Directory? _injectedModelsRoot;
  final List<SherpaModelDefinition> catalog;
  final Map<String, SherpaModelDownloadProgress> _activeProgress = {};
  final Map<String, SherpaDownloadCancellationToken> _activeTokens = {};
  final Map<String, String> _failures = {};

  @visibleForTesting
  static void verifyExtractedArchive(Archive archive, Directory destination) {
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      if (!_isSafeRelativePath(entry.name) || entry.isSymbolicLink) {
        throw const FormatException('Unsafe path in sherpa-onnx model archive');
      }
      final normalized = p.posix.normalize(entry.name.replaceAll('\\', '/'));
      final file = File(
        p.joinAll([destination.path, ...normalized.split('/')]),
      );
      if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
              FileSystemEntityType.file ||
          file.lengthSync() != entry.size) {
        throw FileSystemException(
          'Extracted sherpa-onnx archive file failed size verification',
          file.path,
        );
      }
    }
  }

  Future<Directory> get modelsDirectory async {
    final injected = _injectedModelsRoot;
    if (injected != null) return injected;
    final appData = await AppDirectories.getContentDirectory();
    return Directory(p.join(appData.path, 'asr_models'));
  }

  SherpaModelDefinition modelById(String id) {
    for (final model in catalog) {
      if (model.id == id) return model;
    }
    throw ArgumentError.value(id, 'modelId', 'Unknown sherpa-onnx model');
  }

  Future<Directory> modelDirectory(String modelId) async {
    final model = modelById(modelId);
    _validateDefinition(model);
    final root = await modelsDirectory;
    return Directory(p.join(root.path, model.id));
  }

  Future<bool> isInstalled(String modelId) async {
    final model = modelById(modelId);
    return validateModelDirectory(model, await modelDirectory(modelId));
  }

  Future<bool> validateModelDirectory(
    SherpaModelDefinition model,
    Directory directory,
  ) async {
    _validateDefinition(model);
    if (!await directory.exists()) return false;
    for (final relativePath in model.requiredFiles) {
      final file = File(
        p.joinAll([directory.path, ...relativePath.split('/')]),
      );
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        return false;
      }
      if (await file.length() <= 0) return false;
    }
    return true;
  }

  Future<SherpaModelInstallStatus> statusFor(String modelId) async {
    final model = modelById(modelId);
    final progress = _activeProgress[modelId];
    if (progress != null) {
      return SherpaModelInstallStatus(
        model: model,
        state: SherpaModelInstallState.downloading,
        progress: progress,
      );
    }

    final directory = await modelDirectory(modelId);
    if (await validateModelDirectory(model, directory)) {
      return SherpaModelInstallStatus(
        model: model,
        state: SherpaModelInstallState.installed,
      );
    }
    if (await directory.exists()) {
      return SherpaModelInstallStatus(
        model: model,
        state: SherpaModelInstallState.failed,
        error: _failures[modelId] ?? '模型文件不完整，请重新下载',
      );
    }
    final failure = _failures[modelId];
    return SherpaModelInstallStatus(
      model: model,
      state: failure == null
          ? SherpaModelInstallState.notInstalled
          : SherpaModelInstallState.failed,
      error: failure,
    );
  }

  Future<List<SherpaModelInstallStatus>> listStatuses() {
    return Future.wait(catalog.map((model) => statusFor(model.id)));
  }

  Future<Directory> download(
    String modelId, {
    SherpaModelProgressCallback? onProgress,
    SherpaDownloadCancellationToken? cancellationToken,
  }) async {
    final model = modelById(modelId);
    _validateDefinition(model);
    if (_activeTokens.containsKey(modelId)) {
      throw StateError('Model download is already active: $modelId');
    }

    final target = await modelDirectory(modelId);
    if (await validateModelDirectory(model, target)) return target;

    final token = cancellationToken ?? SherpaDownloadCancellationToken();
    token.throwIfCancelled();
    final root = await modelsDirectory;
    final downloads = Directory(p.join(root.path, '.downloads'));
    final partFile = File(p.join(downloads.path, '${model.id}.tar.bz2.part'));
    final archiveFile = File(p.join(downloads.path, '${model.id}.tar.bz2'));
    final runId = DateTime.now().microsecondsSinceEpoch;
    final staging = Directory(p.join(root.path, '.staging-${model.id}-$runId'));
    if (_activeTokens.containsKey(modelId)) {
      throw StateError('Model download is already active: $modelId');
    }
    _activeTokens[modelId] = token;
    _failures.remove(modelId);

    try {
      _publishProgress(
        SherpaModelDownloadProgress(
          modelId: model.id,
          phase: SherpaModelDownloadPhase.downloading,
          receivedBytes: 0,
          totalBytes: _positiveBytesOrNull(model.downloadBytes),
        ),
        onProgress,
      );
      token.throwIfCancelled();
      await root.create(recursive: true);
      await downloads.create(recursive: true);
      await _deleteFileIfPresent(partFile);
      await _deleteFileIfPresent(archiveFile);
      final downloadedBytes = await _downloadArchive(
        model,
        partFile,
        token,
        onProgress: onProgress,
      );
      token.throwIfCancelled();
      await partFile.rename(archiveFile.path);

      final extracting = SherpaModelDownloadProgress(
        modelId: modelId,
        phase: SherpaModelDownloadPhase.extracting,
        receivedBytes: downloadedBytes,
        totalBytes: downloadedBytes,
      );
      _publishProgress(extracting, onProgress);
      await staging.create(recursive: true);
      await _extractTarBz2Cancellable(archiveFile.path, staging.path, token);
      token.throwIfCancelled();

      final extractedModel = Directory(p.join(staging.path, model.archiveRoot));
      if (!await validateModelDirectory(model, extractedModel)) {
        throw const FormatException(
          'Downloaded archive does not contain all required model files',
        );
      }

      final installing = SherpaModelDownloadProgress(
        modelId: modelId,
        phase: SherpaModelDownloadPhase.installing,
        receivedBytes: downloadedBytes,
        totalBytes: downloadedBytes,
      );
      _publishProgress(installing, onProgress);
      await _installAtomically(extractedModel, target, root, runId);
      if (!await validateModelDirectory(model, target)) {
        throw const FileSystemException(
          'Installed sherpa-onnx model failed validation',
        );
      }
      return target;
    } on SherpaDownloadCancelledException {
      rethrow;
    } catch (error) {
      _failures[modelId] = error.toString();
      rethrow;
    } finally {
      _activeTokens.remove(modelId);
      _activeProgress.remove(modelId);
      await _deleteFileIfPresent(partFile);
      await _deleteFileIfPresent(archiveFile);
      await _deleteFileIfPresent(File('${archiveFile.path}.uncompressed.part'));
      await _deleteDirectoryIfPresent(staging);
    }
  }

  void cancelDownload(String modelId) => _activeTokens[modelId]?.cancel();

  Future<void> delete(String modelId) async {
    final token = _activeTokens[modelId];
    if (token != null) {
      token.cancel();
      throw StateError('Wait for the active model download to stop');
    }
    final directory = await modelDirectory(modelId);
    await _deleteDirectoryIfPresent(directory);
    _failures.remove(modelId);
  }

  void dispose() {
    for (final token in _activeTokens.values) {
      token.cancel();
    }
    if (_ownsHttpClient) _httpClient.close();
  }

  Future<int> _downloadArchive(
    SherpaModelDefinition model,
    File destination,
    SherpaDownloadCancellationToken token, {
    SherpaModelProgressCallback? onProgress,
  }) async {
    final request = http.AbortableRequest(
      'GET',
      model.archiveUri,
      abortTrigger: token.whenCancelled,
    );
    late final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request);
    } on http.RequestAbortedException {
      throw const SherpaDownloadCancelledException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw HttpException(
        'Model download failed with HTTP ${response.statusCode}',
        uri: model.archiveUri,
      );
    }

    final expectedBytes =
        _positiveBytesOrNull(response.contentLength) ??
        _positiveBytesOrNull(model.downloadBytes);
    var receivedBytes = 0;
    final sink = destination.openWrite(mode: FileMode.writeOnly);
    final iterator = StreamIterator<List<int>>(response.stream);
    try {
      _publishProgress(
        SherpaModelDownloadProgress(
          modelId: model.id,
          phase: SherpaModelDownloadPhase.downloading,
          receivedBytes: 0,
          totalBytes: expectedBytes,
        ),
        onProgress,
      );
      while (await _moveNextOrCancel(iterator, token)) {
        final chunk = iterator.current;
        sink.add(chunk);
        receivedBytes += chunk.length;
        _publishProgress(
          SherpaModelDownloadProgress(
            modelId: model.id,
            phase: SherpaModelDownloadPhase.downloading,
            receivedBytes: receivedBytes,
            totalBytes: expectedBytes,
          ),
          onProgress,
        );
      }
      token.throwIfCancelled();
      if (response.contentLength != null &&
          receivedBytes != response.contentLength) {
        throw const HttpException('Model download ended before completion');
      }
      await sink.flush();
      return receivedBytes;
    } finally {
      await iterator.cancel();
      await sink.close();
    }
  }

  Future<bool> _moveNextOrCancel(
    StreamIterator<List<int>> iterator,
    SherpaDownloadCancellationToken token,
  ) async {
    token.throwIfCancelled();
    late final Object result;
    try {
      result = await Future.any<Object>([
        iterator.moveNext(),
        token.whenCancelled.then<Object>((_) => _cancelledMarker),
      ]);
    } on http.RequestAbortedException {
      throw const SherpaDownloadCancelledException();
    }
    if (identical(result, _cancelledMarker)) {
      throw const SherpaDownloadCancelledException();
    }
    return result as bool;
  }

  void _publishProgress(
    SherpaModelDownloadProgress progress,
    SherpaModelProgressCallback? callback,
  ) {
    _activeProgress[progress.modelId] = progress;
    callback?.call(progress);
  }

  static void _validateDefinition(SherpaModelDefinition model) {
    if (!_isSafeSegment(model.id) || !_isSafeSegment(model.archiveRoot)) {
      throw ArgumentError('Unsafe sherpa-onnx model identifier');
    }
    if (model.requiredFiles.isEmpty ||
        model.requiredFiles.any((path) => !_isSafeRelativePath(path))) {
      throw ArgumentError('Unsafe or empty sherpa-onnx required file list');
    }
  }
}

int? _positiveBytesOrNull(int? value) {
  return value != null && value > 0 ? value : null;
}

const Object _cancelledMarker = Object();

Future<void> _extractTarBz2Cancellable(
  String archivePath,
  String destinationPath,
  SherpaDownloadCancellationToken token,
) async {
  final resultPort = ReceivePort();
  final exitPort = ReceivePort();
  Isolate? isolate;
  try {
    isolate = await Isolate.spawn<List<Object>>(_extractTarBz2Isolate, <Object>[
      resultPort.sendPort,
      archivePath,
      destinationPath,
    ], onExit: exitPort.sendPort);
    final result = await Future.any<Object>([
      resultPort.first.then<Object>((value) => value as Object),
      token.whenCancelled.then<Object>((_) => _cancelledMarker),
    ]);
    if (identical(result, _cancelledMarker)) {
      isolate.kill(priority: Isolate.immediate);
      await exitPort.first;
      throw const SherpaDownloadCancelledException();
    }

    final response = result as List<Object?>;
    final type = response.first as String?;
    if (type == null) return;
    final message = response.length > 1
        ? response[1]?.toString() ?? 'Model extraction failed'
        : 'Model extraction failed';
    switch (type) {
      case 'format':
        throw FormatException(message);
      case 'filesystem':
        throw FileSystemException(message);
      default:
        throw StateError(message);
    }
  } finally {
    isolate?.kill(priority: Isolate.immediate);
    resultPort.close();
    exitPort.close();
  }
}

void _extractTarBz2Isolate(List<Object> message) {
  final resultPort = message[0] as SendPort;
  try {
    _extractTarBz2Securely(message[1] as String, message[2] as String);
    resultPort.send(const <String?>[null, null]);
  } on FormatException catch (error) {
    resultPort.send(<String?>['format', error.message.toString()]);
  } on FileSystemException catch (error) {
    resultPort.send(<String?>['filesystem', error.message]);
  } catch (error) {
    resultPort.send(<String?>['other', error.toString()]);
  }
}

void _extractTarBz2Securely(String archivePath, String destinationPath) {
  final tarFile = File('$archivePath.uncompressed.part');
  try {
    final compressedInput = InputFileStream(archivePath);
    final tarOutput = OutputFileStream(tarFile.path);
    try {
      final decoded = BZip2Decoder().decodeStream(
        compressedInput,
        tarOutput,
        verify: true,
      );
      if (!decoded) {
        throw const FormatException('Invalid sherpa-onnx bzip2 archive');
      }
    } finally {
      compressedInput.closeSync();
      tarOutput.closeSync();
    }

    final tarInput = InputFileStream(tarFile.path);
    Archive? archive;
    try {
      archive = TarDecoder().decodeStream(
        tarInput,
        callback: (entry) {
          if (!_isSafeRelativePath(entry.name) || entry.isSymbolicLink) {
            throw const FormatException(
              'Unsafe path in sherpa-onnx model archive',
            );
          }
        },
      );
      _extractArchiveToDiskVerified(archive, destinationPath);
    } finally {
      archive?.clearSync();
      tarInput.closeSync();
    }
  } finally {
    if (tarFile.existsSync()) tarFile.deleteSync();
  }
}

void _extractArchiveToDiskVerified(Archive archive, String destinationPath) {
  final destination = Directory(destinationPath)..createSync(recursive: true);
  for (final entry in archive.files) {
    if (!_isSafeRelativePath(entry.name) || entry.isSymbolicLink) {
      throw const FormatException('Unsafe path in sherpa-onnx model archive');
    }
    final normalized = p.posix.normalize(entry.name.replaceAll('\\', '/'));
    final targetPath = p.joinAll([destination.path, ...normalized.split('/')]);
    if (entry.isDirectory) {
      Directory(targetPath).createSync(recursive: true);
      continue;
    }

    File(targetPath).parent.createSync(recursive: true);
    final output = OutputFileStream(targetPath);
    try {
      entry.writeContent(output);
    } finally {
      output.closeSync();
    }
  }
  SherpaModelManager.verifyExtractedArchive(archive, destination);
}

Future<void> _installAtomically(
  Directory source,
  Directory target,
  Directory root,
  int runId,
) async {
  Directory? previous;
  if (await target.exists()) {
    previous = Directory(
      p.join(root.path, '.previous-${p.basename(target.path)}-$runId'),
    );
    await target.rename(previous.path);
  }
  try {
    await source.rename(target.path);
  } catch (_) {
    if (previous != null && await previous.exists() && !await target.exists()) {
      await previous.rename(target.path);
    }
    rethrow;
  }
  if (previous != null) await _deleteDirectoryIfPresent(previous);
}

bool _isSafeSegment(String value) {
  return value.isNotEmpty &&
      value != '.' &&
      value != '..' &&
      !value.contains('/') &&
      !value.contains('\\') &&
      !value.contains('\u0000') &&
      !RegExp(r'^[A-Za-z]:').hasMatch(value);
}

bool _isSafeRelativePath(String value) {
  if (value.isEmpty || value.contains('\u0000')) return false;
  final slashPath = value.replaceAll('\\', '/');
  if (slashPath.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(slashPath)) {
    return false;
  }
  final normalized = p.posix.normalize(slashPath);
  return normalized != '.' &&
      normalized != '..' &&
      !normalized.startsWith('../');
}

Future<void> _deleteFileIfPresent(File file) async {
  if (await file.exists()) await file.delete();
}

Future<void> _deleteDirectoryIfPresent(Directory directory) async {
  if (await directory.exists()) await directory.delete(recursive: true);
}
