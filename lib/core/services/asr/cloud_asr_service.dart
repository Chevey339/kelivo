import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'asr_service_options.dart';

typedef AsrWebSocketConnector =
    Future<AsrWebSocketConnection> Function(
      Uri uri,
      Map<String, String> headers,
    );

abstract interface class AsrWebSocketConnection {
  Stream<Object?> get messages;

  void send(String message);

  void sendBinary(Uint8List message);

  Future<void> close([int? code, String? reason]);
}

abstract interface class CloudAsrSession {
  /// Emits the complete transcript-so-far whenever the provider revises it.
  Stream<String> get partialTranscripts;

  /// Adds raw little-endian PCM16 mono audio in the configured sample rate.
  Future<void> addPcm16(Uint8List chunk);

  /// Commits buffered audio and resolves with the final transcript.
  Future<String> finish();

  /// Stops network work and releases session resources without committing.
  Future<void> cancel();
}

class AsrException implements Exception {
  const AsrException(this.message);

  final String message;

  @override
  String toString() => 'AsrException: $message';
}

class CloudAsrService {
  CloudAsrService({
    this.httpClient,
    AsrWebSocketConnector? websocketConnector,
    this.completionTimeout = const Duration(seconds: 30),
  }) : _websocketConnector = websocketConnector ?? _defaultWebSocketConnector;

  final http.Client? httpClient;
  final AsrWebSocketConnector _websocketConnector;
  final Duration completionTimeout;

  Future<CloudAsrSession> startSession(AsrServiceOptions options) async {
    if (!options.isConfigured) {
      throw AsrException('${options.name} is not configured');
    }

    switch (options) {
      case OpenAiRealtimeAsrOptions():
        return _startOpenAi(options);
      case DashScopeAsrOptions():
        return _startDashScope(options);
      case QwenAudioAsrOptions():
        return _startQwenAudio(options);
      case VolcengineAsrOptions():
        return _startVolcengine(options);
      case MimoAsrOptions():
        final client = httpClient ?? http.Client();
        return _MimoAsrSession(
          options: options,
          client: client,
          ownsClient: httpClient == null,
          completionTimeout: completionTimeout,
        );
      case StepAsrOptions():
        final client = httpClient ?? http.Client();
        return _StepAsrSession(
          options: options,
          client: client,
          ownsClient: httpClient == null,
          completionTimeout: completionTimeout,
        );
      default:
        throw AsrException('${options.name} is not a cloud ASR service');
    }
  }

  Future<CloudAsrSession> _startQwenAudio(QwenAudioAsrOptions options) async {
    final uri = _webSocketUri(options.websocketUrl, 'Qwen Audio');
    final socket = await _connect(
      label: 'Qwen Audio',
      apiKey: options.apiKey,
      uri: uri,
      headers: {
        'Authorization': 'Bearer ${options.apiKey}',
        if (options.workspaceId.trim().isNotEmpty)
          'X-DashScope-WorkSpace': options.workspaceId.trim(),
      },
    );
    return _QwenAudioAsrSession(
      options: options,
      socket: socket,
      completionTimeout: completionTimeout,
    );
  }

  Future<CloudAsrSession> _startOpenAi(OpenAiRealtimeAsrOptions options) async {
    final uri = _openAiEndpoint(options.websocketUrl);
    final socket = await _connect(
      label: 'OpenAI Realtime',
      apiKey: options.apiKey,
      uri: uri,
      headers: {'Authorization': 'Bearer ${options.apiKey}'},
    );

    return _startRealtimeSession(
      socket: socket,
      label: 'OpenAI Realtime',
      apiKey: options.apiKey,
      sessionUpdate: _openAiSessionUpdate(options),
      addEvent: (audio, _) => {
        'type': 'input_audio_buffer.append',
        'audio': audio,
      },
      commitEvent: (_) => {'type': 'input_audio_buffer.commit'},
    );
  }

  Future<CloudAsrSession> _startDashScope(DashScopeAsrOptions options) async {
    final uri = _dashScopeEndpoint(options.websocketUrl, options.model);
    final socket = await _connect(
      label: 'DashScope',
      apiKey: options.apiKey,
      uri: uri,
      headers: {'Authorization': 'Bearer ${options.apiKey}'},
    );

    return _startRealtimeSession(
      socket: socket,
      label: 'DashScope',
      apiKey: options.apiKey,
      sessionUpdate: _dashScopeSessionUpdate(options),
      addEvent: (audio, eventId) => {
        'event_id': eventId,
        'type': 'input_audio_buffer.append',
        'audio': audio,
      },
      commitEvent: options.vadThreshold > 0
          ? null
          : (eventId) => {
              'event_id': eventId,
              'type': 'input_audio_buffer.commit',
            },
      finishEvent: (eventId) => {'event_id': eventId, 'type': 'session.finish'},
      waitForSessionFinished: true,
    );
  }

  Future<CloudAsrSession> _startVolcengine(VolcengineAsrOptions options) async {
    final uri = _webSocketUri(options.websocketUrl, 'Volcengine');
    final socket = await _connect(
      label: 'Volcengine',
      apiKey: options.apiKey,
      uri: uri,
      headers: {
        'X-Api-Key': options.apiKey,
        'X-Api-Resource-Id': options.resourceId,
        'X-Api-Request-Id': const Uuid().v4(),
        'X-Api-Sequence': '-1',
      },
    );

    final session = _VolcengineAsrSession(
      socket: socket,
      options: options,
      completionTimeout: completionTimeout,
    );
    try {
      session.start();
      return session;
    } catch (_) {
      unawaited(session.cancel());
      throw const AsrException('Volcengine ASR session setup failed');
    }
  }

  Future<AsrWebSocketConnection> _connect({
    required String label,
    required String apiKey,
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    try {
      return await _websocketConnector(uri, headers);
    } catch (_) {
      throw AsrException(_redact('$label ASR connection failed', apiKey));
    }
  }

  CloudAsrSession _startRealtimeSession({
    required AsrWebSocketConnection socket,
    required String label,
    required String apiKey,
    required Map<String, dynamic> sessionUpdate,
    required _AudioEventBuilder addEvent,
    required _ControlEventBuilder? commitEvent,
    _ControlEventBuilder? finishEvent,
    bool waitForSessionFinished = false,
  }) {
    final session = _RealtimeAsrSession(
      socket: socket,
      label: label,
      apiKey: apiKey,
      completionTimeout: completionTimeout,
      addEvent: addEvent,
      commitEvent: commitEvent,
      finishEvent: finishEvent,
      waitForSessionFinished: waitForSessionFinished,
    );
    try {
      session.sendSessionUpdate(sessionUpdate);
      return session;
    } catch (_) {
      unawaited(session.cancel());
      throw AsrException('$label ASR session setup failed');
    }
  }
}

typedef _AudioEventBuilder =
    Map<String, dynamic> Function(String base64Audio, String eventId);
typedef _ControlEventBuilder = Map<String, dynamic> Function(String eventId);

class _VolcengineAsrSession implements CloudAsrSession {
  _VolcengineAsrSession({
    required this._socket,
    required this._options,
    required this._completionTimeout,
  }) {
    _subscription = _socket.messages.listen(
      _handleMessage,
      onError: _handleSocketError,
      onDone: _handleSocketDone,
    );
  }

  final AsrWebSocketConnection _socket;
  final VolcengineAsrOptions _options;
  final Duration _completionTimeout;
  final StreamController<String> _partialController =
      StreamController<String>.broadcast(sync: true);

  late final StreamSubscription<Object?> _subscription;
  Completer<String>? _finishCompleter;
  Future<String>? _finishFuture;
  var _cancelled = false;
  var _cleanedUp = false;
  var _serverFinished = false;
  var _errorPublished = false;
  String _transcript = '';
  AsrException? _terminalError;

  @override
  Stream<String> get partialTranscripts => _partialController.stream;

  void start() {
    _ensureActive();
    _sendBinary(_volcengineConfigFrame(_options));
  }

  @override
  Future<void> addPcm16(Uint8List chunk) async {
    _ensureActive();
    if (chunk.isEmpty) return;
    _sendBinary(
      _volcengineFrame(
        messageType: _volcMessageAudioOnly,
        flags: 0,
        serialization: _volcSerializationNone,
        compression: _volcCompressionNone,
        payload: chunk,
      ),
    );
  }

  @override
  Future<String> finish() {
    return _finishFuture ??= _finishInternal();
  }

  Future<String> _finishInternal() async {
    _ensureActive();
    final completer = Completer<String>();
    _finishCompleter = completer;
    try {
      _sendBinary(
        _volcengineFrame(
          messageType: _volcMessageAudioOnly,
          flags: _volcFlagLastPacket,
          serialization: _volcSerializationNone,
          compression: _volcCompressionNone,
          payload: Uint8List(0),
        ),
      );
      if (_serverFinished && !completer.isCompleted) {
        completer.complete(_transcript);
      }
      final transcript = await completer.future.timeout(
        _completionTimeout,
        onTimeout: () => throw const AsrException(
          'Volcengine ASR timed out waiting for the final transcript',
        ),
      );
      await _cleanup(1000, 'finished');
      return transcript;
    } catch (error, stackTrace) {
      final exception = _safeException(error);
      _publishError(exception, stackTrace);
      await _cleanup(1011, 'failed');
      throw exception;
    }
  }

  @override
  Future<void> cancel() async {
    if (_cleanedUp) return;
    _cancelled = true;
    final completer = _finishCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        const AsrException('Volcengine ASR session was cancelled'),
      );
    }
    await _cleanup(1000, 'cancelled');
  }

  void _handleMessage(Object? message) {
    if (_cleanedUp || _cancelled) return;
    if (message is! List<int>) {
      _fail(const AsrException('Volcengine ASR returned a non-binary frame'));
      return;
    }
    final data = Uint8List.fromList(message);
    if (data.length < 4) {
      _fail(const AsrException('Volcengine ASR returned a truncated frame'));
      return;
    }

    final headerSize = (data[0] & 0x0f) * 4;
    if (headerSize < 4 || data.length < headerSize) {
      _fail(const AsrException('Volcengine ASR returned an invalid frame'));
      return;
    }
    final messageType = (data[1] >> 4) & 0x0f;
    final flags = data[1] & 0x0f;
    final compression = data[2] & 0x0f;

    switch (messageType) {
      case _volcMessageServerResponse:
        _handleTranscriptFrame(data, headerSize, flags, compression);
      case _volcMessageError:
        _handleErrorFrame(data, headerSize, compression);
    }
  }

  void _handleTranscriptFrame(
    Uint8List data,
    int headerSize,
    int flags,
    int compression,
  ) {
    var offset = headerSize;
    if ((flags & _volcFlagHasSequence) != 0) offset += 4;
    final payload = _volcenginePayload(data, offset, compression);
    if (payload == null) {
      _fail(
        const AsrException('Volcengine ASR returned an invalid response frame'),
      );
      return;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payload));
    } catch (_) {
      _fail(const AsrException('Volcengine ASR returned invalid JSON'));
      return;
    }
    if (decoded is! Map) {
      _fail(const AsrException('Volcengine ASR returned an invalid response'));
      return;
    }
    final result = decoded['result'];
    final text = result is Map ? result['text']?.toString().trim() ?? '' : '';
    if (text.isNotEmpty && text != _transcript) {
      _transcript = text;
      if (!_partialController.isClosed) _partialController.add(text);
    }

    if ((flags & _volcFlagLastPacket) != 0) {
      _serverFinished = true;
      final completer = _finishCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(_transcript);
      }
    }
  }

  void _handleErrorFrame(Uint8List data, int headerSize, int compression) {
    var offset = headerSize;
    if (offset + 8 > data.length) {
      _fail(const AsrException('Volcengine ASR returned an invalid error'));
      return;
    }
    final code = ByteData.sublistView(data, offset, offset + 4).getUint32(0);
    offset += 4;
    final payload = _volcenginePayload(data, offset, compression);
    final message = payload == null
        ? ''
        : utf8.decode(payload, allowMalformed: true).trim();
    final suffix = message.isEmpty ? '' : ': $message';
    _fail(
      AsrException(
        _redact('Volcengine ASR server error $code$suffix', _options.apiKey),
      ),
    );
  }

  void _handleSocketError(Object error, StackTrace stackTrace) {
    _fail(
      const AsrException('Volcengine ASR WebSocket failed'),
      stackTrace: stackTrace,
    );
  }

  void _handleSocketDone() {
    if (_cleanedUp || _cancelled) return;
    if (_serverFinished) {
      final completer = _finishCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(_transcript);
      }
      return;
    }
    _fail(
      const AsrException(
        'Volcengine ASR connection closed before the final transcript',
      ),
    );
  }

  void _sendBinary(Uint8List message) {
    try {
      _socket.sendBinary(message);
    } catch (_) {
      throw const AsrException('Volcengine ASR WebSocket send failed');
    }
  }

  void _fail(AsrException exception, {StackTrace? stackTrace}) {
    if (_terminalError != null) return;
    final safe = AsrException(_redact(exception.message, _options.apiKey));
    _terminalError = safe;
    final completer = _finishCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(safe, stackTrace);
    }
    _publishError(safe, stackTrace);
    unawaited(_cleanup(1011, 'failed'));
  }

  void _publishError(Object error, [StackTrace? stackTrace]) {
    if (!_errorPublished && !_partialController.isClosed) {
      _errorPublished = true;
      _partialController.addError(error, stackTrace);
    }
  }

  void _ensureActive() {
    final terminalError = _terminalError;
    if (terminalError != null) throw terminalError;
    if (_cancelled) {
      throw const AsrException('Volcengine ASR session was cancelled');
    }
    if (_cleanedUp) {
      throw const AsrException('Volcengine ASR session is already closed');
    }
  }

  AsrException _safeException(Object error) {
    if (error is AsrException) {
      return AsrException(_redact(error.message, _options.apiKey));
    }
    return const AsrException('Volcengine ASR failed');
  }

  Future<void> _cleanup(int code, String reason) async {
    if (_cleanedUp) return;
    _cleanedUp = true;
    await _subscription.cancel();
    try {
      await _socket.close(code, reason);
    } catch (_) {
      // The session is already terminal; close failures cannot be recovered.
    }
    if (!_partialController.isClosed) await _partialController.close();
  }
}

class _RealtimeAsrSession implements CloudAsrSession {
  _RealtimeAsrSession({
    required this._socket,
    required this._label,
    required this._apiKey,
    required this._completionTimeout,
    required this._addEvent,
    required this._commitEvent,
    required this._finishEvent,
    required this._waitForSessionFinished,
  }) {
    _subscription = _socket.messages.listen(
      _handleMessage,
      onError: _handleSocketError,
      onDone: _handleSocketDone,
    );
  }

  final AsrWebSocketConnection _socket;
  final String _label;
  final String _apiKey;
  final Duration _completionTimeout;
  final _AudioEventBuilder _addEvent;
  final _ControlEventBuilder? _commitEvent;
  final _ControlEventBuilder? _finishEvent;
  final bool _waitForSessionFinished;
  final StreamController<String> _partialController =
      StreamController<String>.broadcast(sync: true);
  final Map<String, String> _partialByItem = {};
  final Map<String, String> _completedByItem = {};
  final List<String> _itemOrder = [];

  late final StreamSubscription<Object?> _subscription;
  Completer<String>? _finishCompleter;
  Future<String>? _finishFuture;
  var _eventSequence = 0;
  var _hasAudio = false;
  var _cancelled = false;
  var _cleanedUp = false;
  var _errorPublished = false;
  String _lastPublished = '';
  AsrException? _terminalError;

  @override
  Stream<String> get partialTranscripts => _partialController.stream;

  void sendSessionUpdate(Map<String, dynamic> event) {
    _ensureActive();
    _sendJson(event);
  }

  @override
  Future<void> addPcm16(Uint8List chunk) async {
    _ensureActive();
    if (chunk.isEmpty) return;
    _hasAudio = true;
    _sendJson(_addEvent(base64Encode(chunk), _nextEventId()));
  }

  @override
  Future<String> finish() {
    return _finishFuture ??= _finishInternal();
  }

  Future<String> _finishInternal() async {
    _ensureActive();
    if (!_hasAudio && _finishEvent == null) {
      await _cleanup(1000, 'finished');
      return _currentTranscript;
    }

    final completer = Completer<String>();
    _finishCompleter = completer;
    try {
      final commitEvent = _commitEvent;
      if (_hasAudio && commitEvent != null) {
        _sendJson(commitEvent(_nextEventId()));
      }
      final finishEvent = _finishEvent;
      if (finishEvent != null) {
        _sendJson(finishEvent(_nextEventId()));
      }
      final transcript = await completer.future.timeout(
        _completionTimeout,
        onTimeout: () => throw AsrException(
          '$_label ASR timed out waiting for the final transcript',
        ),
      );
      await _cleanup(1000, 'finished');
      return transcript;
    } catch (error, stackTrace) {
      final exception = _safeException(error, '$_label ASR failed');
      _publishError(exception, stackTrace);
      await _cleanup(1011, 'failed');
      throw exception;
    }
  }

  @override
  Future<void> cancel() async {
    if (_cleanedUp) return;
    _cancelled = true;
    final completer = _finishCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        AsrException('$_label ASR session was cancelled'),
      );
    }
    await _cleanup(1000, 'cancelled');
  }

  void _handleMessage(Object? message) {
    if (_cleanedUp || _cancelled) return;

    final String text;
    if (message is String) {
      text = message;
    } else if (message is List<int>) {
      text = utf8.decode(message, allowMalformed: true);
    } else {
      _fail(AsrException('$_label ASR returned an unsupported event'));
      return;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      _fail(AsrException('$_label ASR returned invalid JSON'));
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      _fail(AsrException('$_label ASR returned an invalid event'));
      return;
    }

    final type = decoded['type']?.toString() ?? '';
    switch (type) {
      case 'conversation.item.input_audio_transcription.delta':
        final itemId = _itemId(decoded);
        final delta = decoded['delta']?.toString() ?? '';
        if (delta.isNotEmpty) {
          _rememberItem(itemId);
          _partialByItem[itemId] = (_partialByItem[itemId] ?? '') + delta;
          _publishTranscript();
        }
      case 'conversation.item.input_audio_transcription.text':
        final itemId = _itemId(decoded);
        final text = decoded['text']?.toString() ?? '';
        if (text.isNotEmpty) {
          _rememberItem(itemId);
          _partialByItem[itemId] = text;
          _publishTranscript();
        }
      case 'conversation.item.input_audio_transcription.completed':
        final itemId = _itemId(decoded);
        _rememberItem(itemId);
        final transcript =
            decoded['transcript']?.toString().trim() ??
            _partialByItem[itemId]?.trim() ??
            '';
        _partialByItem.remove(itemId);
        _completedByItem[itemId] = transcript;
        _publishTranscript();
        final completer = _finishCompleter;
        if (!_waitForSessionFinished &&
            completer != null &&
            !completer.isCompleted) {
          completer.complete(_currentTranscript);
        }
      case 'conversation.item.input_audio_transcription.failed':
        final error = decoded['error'];
        final serverMessage = error is Map
            ? error['message']?.toString() ?? error['code']?.toString()
            : error?.toString();
        final detail = serverMessage == null || serverMessage.trim().isEmpty
            ? '$_label ASR transcription failed'
            : '$_label ASR transcription failed: $serverMessage';
        _fail(AsrException(_redact(detail, _apiKey)));
      case 'session.finished':
        final completer = _finishCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(_currentTranscript);
        }
      case 'error':
        final error = decoded['error'];
        final serverMessage = error is Map
            ? error['message']?.toString()
            : error?.toString();
        final detail = serverMessage == null || serverMessage.trim().isEmpty
            ? '$_label ASR server returned an error'
            : '$_label ASR server error: $serverMessage';
        _fail(AsrException(_redact(detail, _apiKey)));
    }
  }

  void _handleSocketError(Object error, StackTrace stackTrace) {
    _fail(AsrException('$_label ASR WebSocket failed'), stackTrace: stackTrace);
  }

  void _handleSocketDone() {
    if (_cleanedUp || _cancelled) return;
    _fail(
      AsrException('$_label ASR connection closed before the final transcript'),
    );
  }

  void _fail(AsrException exception, {StackTrace? stackTrace}) {
    if (_terminalError != null) return;
    _terminalError = exception;
    final completer = _finishCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(exception, stackTrace);
    }
    _publishError(exception, stackTrace);
    unawaited(_cleanup(1011, 'failed'));
  }

  void _publishError(Object error, [StackTrace? stackTrace]) {
    if (!_errorPublished && !_partialController.isClosed) {
      _errorPublished = true;
      _partialController.addError(error, stackTrace);
    }
  }

  void _rememberItem(String itemId) {
    if (!_itemOrder.contains(itemId)) _itemOrder.add(itemId);
  }

  void _publishTranscript() {
    final transcript = _currentTranscript;
    if (transcript == _lastPublished || _partialController.isClosed) return;
    _lastPublished = transcript;
    _partialController.add(transcript);
  }

  String get _currentTranscript => _itemOrder
      .map((id) => _completedByItem[id] ?? _partialByItem[id] ?? '')
      .where((text) => text.trim().isNotEmpty)
      .join(' ');

  String _itemId(Map<String, dynamic> event) {
    final id = event['item_id']?.toString() ?? '';
    return id.isEmpty ? 'default' : id;
  }

  String _nextEventId() {
    _eventSequence += 1;
    return 'kelivo_asr_$_eventSequence';
  }

  void _sendJson(Map<String, dynamic> event) {
    try {
      _socket.send(jsonEncode(event));
    } catch (_) {
      throw AsrException('$_label ASR WebSocket send failed');
    }
  }

  void _ensureActive() {
    final terminalError = _terminalError;
    if (terminalError != null) throw terminalError;
    if (_cancelled) {
      throw AsrException('$_label ASR session was cancelled');
    }
    if (_cleanedUp) {
      throw AsrException('$_label ASR session is already closed');
    }
  }

  AsrException _safeException(Object error, String fallback) {
    if (error is AsrException) {
      return AsrException(_redact(error.message, _apiKey));
    }
    return AsrException(fallback);
  }

  Future<void> _cleanup(int code, String reason) async {
    if (_cleanedUp) return;
    _cleanedUp = true;
    await _subscription.cancel();
    try {
      await _socket.close(code, reason);
    } catch (_) {
      // The session is already terminal; close failures cannot be recovered.
    }
    if (!_partialController.isClosed) await _partialController.close();
  }
}

class _MimoAsrSession implements CloudAsrSession {
  _MimoAsrSession({
    required this._options,
    required this._client,
    required this._ownsClient,
    required this._completionTimeout,
  });

  final MimoAsrOptions _options;
  final http.Client _client;
  final bool _ownsClient;
  final Duration _completionTimeout;
  final BytesBuilder _pcm = BytesBuilder();
  final StreamController<String> _partialController =
      StreamController<String>.broadcast(sync: true);
  final List<String> _completedTranscripts = [];

  Future<String>? _finishFuture;
  var _cancelled = false;
  var _cleanedUp = false;
  AsrException? _terminalError;

  @override
  Stream<String> get partialTranscripts => _partialController.stream;

  @override
  Future<void> addPcm16(Uint8List chunk) async {
    _ensureActive();
    if (chunk.isEmpty) return;
    _pcm.add(chunk);
    if (_pcm.length >= _segmentByteLimit) {
      try {
        await _flushSegment();
      } catch (error) {
        throw await _terminate(error);
      }
    }
  }

  @override
  Future<String> finish() {
    return _finishFuture ??= _finishInternal();
  }

  Future<String> _finishInternal() async {
    _ensureActive();
    try {
      await _flushSegment();
      final transcript = _currentTranscript;
      await _cleanup();
      return transcript;
    } catch (error) {
      throw await _terminate(error);
    }
  }

  Future<void> _flushSegment() async {
    final pcm = _pcm.takeBytes();
    if (pcm.isEmpty) return;
    if (pcm.length.isOdd) {
      throw const AsrException('MiMo ASR received an incomplete PCM16 sample');
    }
    final transcript = await _transcribeSegment(pcm);
    if (transcript.isEmpty) return;
    _completedTranscripts.add(transcript);
    if (!_partialController.isClosed) {
      _partialController.add(_currentTranscript);
    }
  }

  Future<String> _transcribeSegment(Uint8List pcm) async {
    try {
      final wav = _pcm16MonoToWav(pcm, _options.sampleRate);
      final body = <String, dynamic>{
        'model': _options.model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_audio',
                'input_audio': {
                  'data': 'data:audio/wav;base64,${base64Encode(wav)}',
                },
              },
            ],
          },
        ],
        if (_options.language.trim().isNotEmpty)
          'asr_options': {'language': _options.language},
      };
      final response = await _client
          .post(
            _mimoEndpoint(_options.baseUrl),
            headers: {
              'api-key': _options.apiKey,
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_completionTimeout);

      if (_cancelled) {
        throw const AsrException('MiMo ASR session was cancelled');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _responseError(response.body);
        final suffix = detail.isEmpty ? '' : ': $detail';
        throw AsrException(
          _redact(
            'MiMo ASR request failed with HTTP ${response.statusCode}$suffix',
            _options.apiKey,
          ),
        );
      }

      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw const AsrException('MiMo ASR returned invalid JSON');
      }
      final transcript = _mimoTranscript(decoded);
      if (transcript == null) {
        throw const AsrException(
          'MiMo ASR response did not contain a transcript',
        );
      }
      return transcript;
    } on TimeoutException {
      throw const AsrException('MiMo ASR request timed out');
    } on AsrException catch (error) {
      throw AsrException(_redact(error.message, _options.apiKey));
    } catch (_) {
      throw const AsrException('MiMo ASR request failed');
    }
  }

  @override
  Future<void> cancel() async {
    if (_cleanedUp) return;
    _cancelled = true;
    await _cleanup();
  }

  void _ensureActive() {
    final terminalError = _terminalError;
    if (terminalError != null) throw terminalError;
    if (_cancelled) {
      throw const AsrException('MiMo ASR session was cancelled');
    }
    if (_cleanedUp) {
      throw const AsrException('MiMo ASR session is already closed');
    }
  }

  int get _segmentByteLimit {
    const maximumBytes = 6 * 1024 * 1024;
    final seconds = _options.segmentDurationSec;
    if (seconds <= 0) return maximumBytes;
    final timedBytes = _options.sampleRate * 2 * seconds;
    return timedBytes < maximumBytes ? timedBytes : maximumBytes;
  }

  String get _currentTranscript => _completedTranscripts.join(' ');

  Future<AsrException> _terminate(Object error) async {
    final existing = _terminalError;
    if (existing != null) return existing;
    final exception = error is AsrException
        ? AsrException(_redact(error.message, _options.apiKey))
        : const AsrException('MiMo ASR request failed');
    _terminalError = exception;
    _publishError(exception);
    await _cleanup();
    return exception;
  }

  void _publishError(AsrException exception) {
    if (!_partialController.isClosed) {
      _partialController.addError(exception);
    }
  }

  Future<void> _cleanup() async {
    if (_cleanedUp) return;
    _cleanedUp = true;
    if (_ownsClient) _client.close();
    if (!_partialController.isClosed) await _partialController.close();
  }
}

class _StepAsrSession implements CloudAsrSession {
  _StepAsrSession({
    required this._options,
    required this._client,
    required this._ownsClient,
    required this._completionTimeout,
  });

  final StepAsrOptions _options;
  final http.Client _client;
  final bool _ownsClient;
  final Duration _completionTimeout;
  final BytesBuilder _pcm = BytesBuilder();
  final StreamController<String> _partialController =
      StreamController<String>.broadcast(sync: true);
  final List<String> _completedTranscripts = [];

  Future<String>? _finishFuture;
  var _cancelled = false;
  var _cleanedUp = false;
  AsrException? _terminalError;

  @override
  Stream<String> get partialTranscripts => _partialController.stream;

  @override
  Future<void> addPcm16(Uint8List chunk) async {
    _ensureActive();
    if (chunk.isEmpty) return;
    _pcm.add(chunk);
    if (_pcm.length >= _segmentByteLimit) {
      try {
        await _flushSegment();
      } catch (error) {
        throw await _terminate(error);
      }
    }
  }

  @override
  Future<String> finish() {
    return _finishFuture ??= _finishInternal();
  }

  Future<String> _finishInternal() async {
    _ensureActive();
    try {
      await _flushSegment();
      final transcript = _currentTranscript;
      await _cleanup();
      return transcript;
    } catch (error) {
      throw await _terminate(error);
    }
  }

  Future<void> _flushSegment() async {
    final pcm = _pcm.takeBytes();
    if (pcm.isEmpty || pcm.length < _stepMinimumSegmentBytes) return;
    if (pcm.length.isOdd) {
      throw const AsrException('Step ASR received an incomplete PCM16 sample');
    }
    final transcript = await _transcribeSegment(pcm);
    if (transcript.isEmpty) return;
    _completedTranscripts.add(transcript);
    if (!_partialController.isClosed) {
      _partialController.add(_currentTranscript);
    }
  }

  Future<String> _transcribeSegment(Uint8List pcm) async {
    AsrException? lastError;
    for (var attempt = 1; attempt <= _stepMaximumRetries; attempt++) {
      try {
        return await _transcribeOnce(pcm);
      } on AsrException catch (error) {
        lastError = AsrException(_redact(error.message, _options.apiKey));
      } on TimeoutException {
        lastError = const AsrException('Step ASR request timed out');
      } catch (_) {
        lastError = const AsrException('Step ASR request failed');
      }
      if (_cancelled) {
        throw const AsrException('Step ASR session was cancelled');
      }
      if (attempt < _stepMaximumRetries) {
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
    throw lastError ?? const AsrException('Step ASR request failed');
  }

  Future<String> _transcribeOnce(Uint8List pcm) async {
    final transcription = <String, dynamic>{
      'model': _options.model,
      'enable_itn': _options.enableItn,
      'enable_timestamp': _options.enableTimestamp,
      if (_options.language.trim().isNotEmpty) 'language': _options.language,
      if (_options.hotwords.isNotEmpty) 'hotwords': _options.hotwords,
    };
    final body = <String, dynamic>{
      'audio': {
        'data': base64Encode(pcm),
        'input': {
          'transcription': transcription,
          'format': {
            'type': 'pcm',
            'codec': 'pcm_s16le',
            'rate': _options.sampleRate,
            'bits': 16,
            'channel': 1,
          },
        },
      },
    };
    final response = await _client
        .post(
          _stepEndpoint(_options.baseUrl),
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${_options.apiKey}',
            HttpHeaders.acceptHeader: 'text/event-stream',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_completionTimeout);

    if (_cancelled) {
      throw const AsrException('Step ASR session was cancelled');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _responseError(response.body);
      final suffix = detail.isEmpty ? '' : ': $detail';
      throw AsrException(
        _redact(
          'Step ASR request failed with HTTP ${response.statusCode}$suffix',
          _options.apiKey,
        ),
      );
    }
    return _parseStepSseTranscript(utf8.decode(response.bodyBytes));
  }

  @override
  Future<void> cancel() async {
    if (_cleanedUp) return;
    _cancelled = true;
    await _cleanup();
  }

  void _ensureActive() {
    final terminalError = _terminalError;
    if (terminalError != null) throw terminalError;
    if (_cancelled) {
      throw const AsrException('Step ASR session was cancelled');
    }
    if (_cleanedUp) {
      throw const AsrException('Step ASR session is already closed');
    }
  }

  int get _segmentByteLimit {
    const maximumBytes = 6 * 1024 * 1024;
    final seconds = _options.segmentDurationSec;
    if (seconds <= 0) return maximumBytes;
    final timedBytes = _options.sampleRate * 2 * seconds;
    return timedBytes < maximumBytes ? timedBytes : maximumBytes;
  }

  String get _currentTranscript => _completedTranscripts.join(' ');

  Future<AsrException> _terminate(Object error) async {
    final existing = _terminalError;
    if (existing != null) return existing;
    final exception = error is AsrException
        ? AsrException(_redact(error.message, _options.apiKey))
        : const AsrException('Step ASR request failed');
    _terminalError = exception;
    if (!_partialController.isClosed) {
      _partialController.addError(exception);
    }
    await _cleanup();
    return exception;
  }

  Future<void> _cleanup() async {
    if (_cleanedUp) return;
    _cleanedUp = true;
    if (_ownsClient) _client.close();
    if (!_partialController.isClosed) await _partialController.close();
  }
}

/// Qwen Audio 3.0 ASR via `/api-ws/v1/inference`:
/// run-task → binary PCM → result-generated → finish-task.
class _QwenAudioAsrSession implements CloudAsrSession {
  _QwenAudioAsrSession({
    required this._options,
    required this._socket,
    required this._completionTimeout,
  }) : _taskId = const Uuid().v4() {
    _subscription = _socket.messages.listen(
      _handleMessage,
      onError: (Object e, StackTrace st) => _fail(e, stackTrace: st),
      onDone: () {
        if (_finishCompleter != null && !_finishCompleter!.isCompleted) {
          _finishCompleter!.complete(_transcript);
        }
      },
    );
    _socket.send(
      jsonEncode({
        'header': {
          'action': 'run-task',
          'task_id': _taskId,
          'streaming': 'duplex',
        },
        'payload': {
          'task_group': 'audio',
          'task': 'asr',
          'function': 'recognition',
          'model': _options.model,
          'parameters': {
            'format': _options.format,
            'sample_rate': _options.sampleRate,
          },
          'input': {},
        },
      }),
    );
  }

  final QwenAudioAsrOptions _options;
  final AsrWebSocketConnection _socket;
  final Duration _completionTimeout;
  final String _taskId;
  final StreamController<String> _partialController =
      StreamController<String>.broadcast(sync: true);

  late final StreamSubscription<Object?> _subscription;
  final Completer<void> _started = Completer<void>();
  Completer<String>? _finishCompleter;
  Future<String>? _finishFuture;

  /// Finalized sentences accumulated across `result-generated` events.
  var _finalizedTranscript = '';

  /// Full transcript shown to callers: finalized + current partial sentence.
  var _transcript = '';
  var _cleanedUp = false;
  var _cancelled = false;
  AsrException? _terminalError;

  @override
  Stream<String> get partialTranscripts => _partialController.stream;

  @override
  Future<void> addPcm16(Uint8List chunk) async {
    _ensureActive();
    if (chunk.isEmpty) return;
    if (!_started.isCompleted) {
      await _started.future.timeout(_completionTimeout);
    }
    _socket.sendBinary(chunk);
  }

  @override
  Future<String> finish() {
    return _finishFuture ??= _finishInternal();
  }

  Future<String> _finishInternal() async {
    _ensureActive();
    final completer = Completer<String>();
    _finishCompleter = completer;
    try {
      if (!_started.isCompleted) {
        await _started.future.timeout(_completionTimeout);
      }
      _socket.send(
        jsonEncode({
          'header': {
            'action': 'finish-task',
            'task_id': _taskId,
            'streaming': 'duplex',
          },
          'payload': {'input': {}},
        }),
      );
      return await completer.future.timeout(_completionTimeout);
    } on TimeoutException {
      throw const AsrException('Qwen Audio ASR timed out');
    } finally {
      await _cleanup(1000, 'finished');
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    _terminalError ??= const AsrException(
      'Qwen Audio ASR session was cancelled',
    );
    final completer = _finishCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(_terminalError!);
    }
    await _cleanup(1000, 'cancelled');
  }

  void _handleMessage(Object? event) {
    if (event is! String) return;
    Map<String, dynamic>? obj;
    try {
      obj = jsonDecode(event) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final header = (obj['header'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = (header['event'] ?? '').toString();
    if (name == 'task-started') {
      if (!_started.isCompleted) _started.complete();
      return;
    }
    if (name == 'result-generated') {
      final payload = (obj['payload'] as Map?)?.cast<String, dynamic>() ?? {};
      final output = (payload['output'] as Map?)?.cast<String, dynamic>() ?? {};
      final sentence =
          (output['sentence'] as Map?)?.cast<String, dynamic>() ?? {};
      final text = (sentence['text'] ?? '').toString();
      if (text.isEmpty) return;
      // Official Fun-ASR / Qwen Audio protocol returns the *current* sentence
      // only. Accumulate finalized sentences, then append the active partial.
      if (_isQwenAudioSentenceEnd(sentence)) {
        _finalizedTranscript = combineQwenAudioTranscript(
          _finalizedTranscript,
          text,
        );
        _transcript = _finalizedTranscript;
      } else {
        _transcript = combineQwenAudioTranscript(_finalizedTranscript, text);
      }
      if (!_partialController.isClosed) {
        _partialController.add(_transcript);
      }
      return;
    }
    if (name == 'task-finished') {
      final completer = _finishCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(_transcript);
      }
      return;
    }
    if (name == 'task-failed') {
      final msg = (header['error_message'] ?? header['error_code'] ?? name)
          .toString();
      _fail(AsrException('Qwen Audio ASR failed: $msg'));
    }
  }

  void _fail(Object error, {StackTrace? stackTrace}) {
    final safe = error is AsrException
        ? error
        : const AsrException('Qwen Audio ASR failed');
    _terminalError = safe;
    if (!_started.isCompleted) {
      _started.completeError(safe, stackTrace);
    }
    final completer = _finishCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(safe, stackTrace);
    }
    if (!_partialController.isClosed) {
      _partialController.addError(safe, stackTrace);
    }
    unawaited(_cleanup(1011, 'failed'));
  }

  void _ensureActive() {
    final terminalError = _terminalError;
    if (terminalError != null) throw terminalError;
    if (_cancelled) {
      throw const AsrException('Qwen Audio ASR session was cancelled');
    }
    if (_cleanedUp) {
      throw const AsrException('Qwen Audio ASR session is already closed');
    }
  }

  Future<void> _cleanup(int code, String reason) async {
    if (_cleanedUp) return;
    _cleanedUp = true;
    await _subscription.cancel();
    try {
      await _socket.close(code, reason);
    } catch (_) {}
    if (!_partialController.isClosed) await _partialController.close();
  }
}

/// Mirrors DashScope `RecognitionResult.is_sentence_end`.
bool _isQwenAudioSentenceEnd(Map<String, dynamic> sentence) {
  final flag = sentence['sentence_end'];
  if (flag is bool) return flag;
  if (flag != null) {
    final normalized = flag.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return false;
}

/// Joins Qwen Audio finalized/partial segments.
///
/// Inserts a space for Latin text boundaries (including when the previous
/// segment ends with Latin punctuation) while leaving CJK sentence joins
/// unspaced.
@visibleForTesting
String combineQwenAudioTranscript(String prefix, String next) {
  if (prefix.isEmpty) return next;
  if (next.isEmpty) return prefix;
  if (RegExp(r'^\s').hasMatch(next)) return '$prefix$next';
  final prefixEndsLatinWord = RegExp(r'[A-Za-z0-9]$').hasMatch(prefix);
  final prefixEndsLatinPunct = RegExp(r'''[.!?…,;:'")\]]$''').hasMatch(prefix);
  final nextStartsLatinWord = RegExp(r'^[A-Za-z0-9]').hasMatch(next);
  final needsSpace =
      nextStartsLatinWord && (prefixEndsLatinWord || prefixEndsLatinPunct);
  return needsSpace ? '$prefix $next' : '$prefix$next';
}

class _IoAsrWebSocketConnection implements AsrWebSocketConnection {
  _IoAsrWebSocketConnection(this._socket);

  final WebSocket _socket;

  @override
  Stream<Object?> get messages => _socket;

  @override
  void send(String message) => _socket.add(message);

  @override
  void sendBinary(Uint8List message) => _socket.add(message);

  @override
  Future<void> close([int? code, String? reason]) async {
    await _socket.close(code, reason);
  }
}

Future<AsrWebSocketConnection> _defaultWebSocketConnector(
  Uri uri,
  Map<String, String> headers,
) async {
  final socket = await WebSocket.connect(uri.toString(), headers: headers);
  return _IoAsrWebSocketConnection(socket);
}

const _volcMessageFullClientRequest = 0x01;
const _volcMessageAudioOnly = 0x02;
const _volcMessageServerResponse = 0x09;
const _volcMessageError = 0x0f;
const _volcSerializationNone = 0x00;
const _volcSerializationJson = 0x01;
const _volcCompressionNone = 0x00;
const _volcCompressionGzip = 0x01;
const _volcFlagHasSequence = 0x01;
const _volcFlagLastPacket = 0x02;
const _stepMinimumSegmentBytes = 3200;
const _stepMaximumRetries = 3;

Uint8List _volcengineConfigFrame(VolcengineAsrOptions options) {
  final audio = <String, dynamic>{
    'format': 'pcm',
    'rate': 16000,
    'bits': 16,
    'channel': 1,
    if (options.language.trim().isNotEmpty) 'language': options.language,
  };
  final body = <String, dynamic>{
    'user': {'uid': 'kelivo'},
    'audio': audio,
    'request': {
      'model_name': 'bigmodel',
      'enable_itn': true,
      'enable_punc': true,
      'show_utterances': true,
      'result_type': 'full',
    },
  };
  final payload = Uint8List.fromList(
    GZipCodec().encode(utf8.encode(jsonEncode(body))),
  );
  return _volcengineFrame(
    messageType: _volcMessageFullClientRequest,
    flags: 0,
    serialization: _volcSerializationJson,
    compression: _volcCompressionGzip,
    payload: payload,
  );
}

Uint8List _volcengineFrame({
  required int messageType,
  required int flags,
  required int serialization,
  required int compression,
  required Uint8List payload,
}) {
  final data = ByteData(8 + payload.length);
  data.setUint8(0, 0x11);
  data.setUint8(1, (messageType << 4) | (flags & 0x0f));
  data.setUint8(2, (serialization << 4) | (compression & 0x0f));
  data.setUint8(3, 0);
  data.setUint32(4, payload.length, Endian.big);
  data.buffer.asUint8List(8).setAll(0, payload);
  return data.buffer.asUint8List();
}

Uint8List? _volcenginePayload(
  Uint8List frame,
  int sizeOffset,
  int compression,
) {
  if (sizeOffset < 0 || sizeOffset + 4 > frame.length) return null;
  final size = ByteData.sublistView(
    frame,
    sizeOffset,
    sizeOffset + 4,
  ).getUint32(0, Endian.big);
  final payloadOffset = sizeOffset + 4;
  if (payloadOffset + size > frame.length) return null;
  final payload = frame.sublist(payloadOffset, payloadOffset + size);
  if (compression == _volcCompressionNone) return Uint8List.fromList(payload);
  if (compression != _volcCompressionGzip) return null;
  try {
    return Uint8List.fromList(GZipCodec().decode(payload));
  } catch (_) {
    return null;
  }
}

Uri _openAiEndpoint(String value) {
  final uri = _webSocketUri(value, 'OpenAI Realtime');
  if (uri.queryParameters.containsKey('intent')) return uri;
  return uri.replace(
    queryParameters: {...uri.queryParameters, 'intent': 'transcription'},
  );
}

Uri _dashScopeEndpoint(String value, String model) {
  final uri = _webSocketUri(value, 'DashScope');
  if (uri.queryParameters.containsKey('model')) return uri;
  return uri.replace(queryParameters: {...uri.queryParameters, 'model': model});
}

Uri _webSocketUri(String value, String label) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'ws' && uri.scheme != 'wss') ||
      uri.host.isEmpty) {
    throw AsrException('$label ASR WebSocket URL is invalid');
  }
  return uri;
}

Uri _mimoEndpoint(String value) {
  final base = value.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse('$base/chat/completions');
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    throw const AsrException('MiMo ASR base URL is invalid');
  }
  return uri;
}

Uri _stepEndpoint(String value) {
  final base = value.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse('$base/v1/audio/asr/sse');
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    throw const AsrException('Step ASR base URL is invalid');
  }
  return uri;
}

String _parseStepSseTranscript(String body) {
  final transcript = StringBuffer();
  String? eventType;
  final dataLines = <String>[];

  bool dispatchEvent() {
    if (eventType == null && dataLines.isEmpty) return false;
    final data = dataLines.join('\n');
    final shouldStop = _handleStepSseEvent(eventType, data, transcript);
    eventType = null;
    dataLines.clear();
    return shouldStop;
  }

  for (final line in const LineSplitter().convert(body)) {
    if (line.isEmpty) {
      if (dispatchEvent()) break;
      continue;
    }
    if (line.startsWith(':')) continue;
    final separator = line.indexOf(':');
    final field = separator < 0 ? line : line.substring(0, separator);
    final value = separator < 0
        ? ''
        : line.substring(separator + 1).replaceFirst(RegExp(r'^ '), '');
    switch (field) {
      case 'event':
        eventType = value;
      case 'data':
        dataLines.add(value);
    }
  }
  dispatchEvent();
  return transcript.toString().trim();
}

bool _handleStepSseEvent(
  String? eventType,
  String data,
  StringBuffer transcript,
) {
  if (data == '[DONE]') return true;
  Object? decoded;
  try {
    decoded = jsonDecode(data);
  } catch (_) {
    decoded = null;
  }
  final json = decoded is Map ? decoded : null;
  final type = eventType?.trim().isNotEmpty == true
      ? eventType!.trim()
      : json?['type']?.toString();

  switch (type) {
    case 'transcript.text.delta':
      transcript.write(
        _extractStepTranscriptText(json, json == null ? data : ''),
      );
      return false;
    case 'transcript.text.done':
      final finalText = _extractStepTranscriptText(json, '');
      if (finalText.trim().isNotEmpty) {
        transcript.clear();
        transcript.write(finalText);
      }
      return true;
    case 'error':
      throw AsrException(
        'Step ASR server error: ${_extractStepErrorMessage(json, data)}',
      );
    default:
      final text = _extractStepTranscriptText(json, '');
      if (text.trim().isNotEmpty) transcript.write(text);
      return false;
  }
}

String _extractStepTranscriptText(Map? json, String fallback) {
  if (json == null) return fallback;
  for (final key in const ['delta', 'text', 'content', 'transcript']) {
    final value = json[key];
    if (value == null) continue;
    if (value is Map) {
      final nested = _extractStepTranscriptText(value, '');
      if (nested.trim().isNotEmpty) return nested;
    } else {
      final text = value.toString();
      if (text.trim().isNotEmpty) return text;
    }
  }
  for (final key in const ['data', 'result', 'transcript']) {
    final value = json[key];
    if (value is! Map) continue;
    final nested = _extractStepTranscriptText(value, '');
    if (nested.trim().isNotEmpty) return nested;
  }
  return fallback;
}

String _extractStepErrorMessage(Map? json, String fallback) {
  if (json == null) return fallback;
  final error = json['error'];
  if (error is Map) {
    final message = error['message']?.toString() ?? '';
    if (message.trim().isNotEmpty) return message;
  }
  final message = json['message']?.toString() ?? '';
  return message.trim().isEmpty ? fallback : message;
}

Map<String, dynamic> _openAiSessionUpdate(OpenAiRealtimeAsrOptions options) {
  final transcription = <String, dynamic>{'model': options.model};
  if (options.language.trim().isNotEmpty) {
    if (options.model == 'gpt-live-transcribe') {
      transcription['languages'] = [options.language];
    } else {
      transcription['language'] = options.language;
    }
  }
  if (options.prompt.trim().isNotEmpty) {
    transcription['prompt'] = options.prompt;
  }

  return {
    'type': 'session.update',
    'session': {
      'type': 'transcription',
      'audio': {
        'input': {
          'format': {'type': 'audio/pcm', 'rate': options.sampleRate},
          'transcription': transcription,
          'noise_reduction': {'type': 'near_field'},
          'turn_detection': options.vadThreshold > 0
              ? {
                  'type': 'server_vad',
                  'threshold': options.vadThreshold,
                  'prefix_padding_ms': options.prefixPaddingMs,
                  'silence_duration_ms': options.silenceDurationMs,
                }
              : null,
        },
      },
    },
  };
}

Map<String, dynamic> _dashScopeSessionUpdate(DashScopeAsrOptions options) => {
  'event_id': 'kelivo_asr_session_update',
  'type': 'session.update',
  'session': {
    'input_audio_format': 'pcm',
    'sample_rate': options.sampleRate,
    'input_audio_transcription': {
      if (options.language.trim().isNotEmpty) 'language': options.language,
    },
    'turn_detection': options.vadThreshold > 0
        ? {
            'type': 'server_vad',
            'threshold': options.vadThreshold,
            'silence_duration_ms': options.silenceDurationMs,
          }
        : null,
  },
};

String _responseError(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString().trim();
      }
      if (decoded['message'] != null) {
        return decoded['message'].toString().trim();
      }
    }
  } catch (_) {
    // Do not include arbitrary response bodies in errors; they may echo secrets.
  }
  return '';
}

String? _mimoTranscript(Object? decoded) {
  if (decoded is! Map) return null;
  final choices = decoded['choices'];
  if (choices is! List || choices.isEmpty || choices.first is! Map) return null;
  final message = (choices.first as Map)['message'];
  if (message is! Map || !message.containsKey('content')) return null;
  return message['content']?.toString().trim() ?? '';
}

Uint8List _pcm16MonoToWav(Uint8List pcm, int sampleRate) {
  final result = ByteData(44 + pcm.length);
  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      result.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  ascii(0, 'RIFF');
  result.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  result.setUint32(16, 16, Endian.little);
  result.setUint16(20, 1, Endian.little);
  result.setUint16(22, 1, Endian.little);
  result.setUint32(24, sampleRate, Endian.little);
  result.setUint32(28, sampleRate * 2, Endian.little);
  result.setUint16(32, 2, Endian.little);
  result.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  result.setUint32(40, pcm.length, Endian.little);
  result.buffer.asUint8List(44).setAll(0, pcm);
  return result.buffer.asUint8List();
}

String _redact(String message, String apiKey) {
  final secret = apiKey.trim();
  return secret.isEmpty ? message : message.replaceAll(secret, '[REDACTED]');
}
