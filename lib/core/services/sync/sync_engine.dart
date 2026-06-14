import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../providers/sync_provider.dart';
import '../chat/chat_service.dart';
import 'sync_change_log.dart';
import 'sync_metadata.dart';
import 'sync_transport.dart';

class SyncEngine {
  static const int _debounceMillis = 30000;
  static const int _maxBatchAgeMillis = 300000;

  final SyncChangeLog _changeLog;
  final SyncMetadata _metadata;
  final ChatService _chatService;
  final SyncProvider _provider;
  SyncTransport? _transport;

  Timer? _debounceTimer;
  Timer? _pullTimer;
  bool _disposed = false;
  int _lastKnownChangeCount = 0;
  int? _flushDeadline;

  SyncEngine({
    required SyncChangeLog changeLog,
    required SyncMetadata metadata,
    required ChatService chatService,
    required SyncProvider provider,
    SyncTransport? transport,
  })  : _changeLog = changeLog,
        _metadata = metadata,
        _chatService = chatService,
        _provider = provider,
        _transport = transport;

  void setTransport(SyncTransport transport) {
    _transport = transport;
  }

  bool get _canSync => _transport != null && _metadata.enabled;

  void notifyChange() {
    if (!_canSync || _disposed) return;
    _debounceTimer?.cancel();
    _flushDeadline ??=
        DateTime.now().millisecondsSinceEpoch + _maxBatchAgeMillis;
    _debounceTimer = Timer(
      const Duration(milliseconds: _debounceMillis),
      _onDebounceElapsed,
    );
  }

  Future<void> _onDebounceElapsed() async {
    if (!_canSync || _disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_flushDeadline != null && now >= _flushDeadline!) {
      await _flush();
      return;
    }
    final count = _changeLog.pendingCount;
    if (count > _lastKnownChangeCount) {
      _lastKnownChangeCount = count;
      _debounceTimer = Timer(
        const Duration(milliseconds: _debounceMillis),
        _onDebounceElapsed,
      );
      return;
    }
    await _flush();
  }

  Future<void> _flush() async {
    _flushDeadline = null;
    _lastKnownChangeCount = 0;
    await push();
    await pull();
  }

  Future<void> startPeriodicPull() async {
    final interval = _metadata.pullIntervalSeconds;
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(Duration(seconds: interval), (_) async {
      if (_canSync && !_disposed) {
        await pull();
      }
    });
  }

  void stopPeriodicPull() {
    _pullTimer?.cancel();
    _pullTimer = null;
  }

  Future<void> triggerImmediate() async {
    if (!_canSync || _disposed) return;
    _debounceTimer?.cancel();
    _flushDeadline = null;
    _lastKnownChangeCount = 0;
    await push();
    await pull();
  }

  Future<void> push() async {
    if (!_canSync || _disposed) return;
    final entries = _changeLog.getUnsynced();
    if (entries.isEmpty) return;

    _provider.setStatus(SyncStatus.pushing);
    try {
      final batchId = const Uuid().v4();
      _changeLog.markBatch(entries, batchId);

      final batch = {
        'batchId': batchId,
        'deviceId': _metadata.deviceId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'changes': entries.map((e) => e.toJson()).toList(),
      };
      final bytes = utf8.encode(jsonEncode(batch));

      final filename =
          '${DateTime.now().millisecondsSinceEpoch}_${_metadata.deviceId}_$batchId.json';

      await _transport!.uploadBytes('.kelivo_sync/changes/$filename', bytes);

      _changeLog.deleteByBatchId(batchId);
      _changeLog.deleteSynced();
      _provider.setLastSyncAt(DateTime.now());
      _provider.setStatus(SyncStatus.idle);
    } catch (e) {
      _provider.recordError(e.toString());
    }
  }

  Future<void> pull() async {
    if (!_canSync || _disposed) return;

    _provider.setStatus(SyncStatus.pulling);
    try {
      final since = _metadata.lastSyncAt;
      final files = await _transport!.listFiles('.kelivo_sync/changes/');

      final sorted = <RemoteFile>[];
      for (final f in files) {
        final name = f.path.split('/').last;
        final parts = name.split('_');
        if (parts.length < 3) continue;
        final ts = int.tryParse(parts[0]);
        final deviceId = parts[1];
        if (ts == null) continue;
        if (deviceId == _metadata.deviceId) continue;
        if (since != null && ts <= since) continue;
        sorted.add(f);
      }
      sorted.sort((a, b) => a.path.compareTo(b.path));

      int? lastAppliedTimestamp;
      for (final file in sorted) {
        try {
          final bytes = await _transport!.downloadBytes(file.path);
          final batch = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          final changes = batch['changes'] as List<dynamic>;
          for (final c in changes) {
            await _applyChange(c as Map<String, dynamic>);
          }
          lastAppliedTimestamp = batch['createdAt'] as int;
        } catch (e) {
          _provider.recordError('Failed to apply ${file.path}: $e');
          return;
        }
      }

      if (lastAppliedTimestamp != null) {
        _metadata.lastSyncAt = lastAppliedTimestamp;
      }
      _provider.setLastSyncAt(DateTime.now());
      _provider.setStatus(SyncStatus.idle);
    } catch (e) {
      _provider.recordError(e.toString());
    }
  }

  Future<void> _applyChange(Map<String, dynamic> change) async {
    final domain = change['domain'] as String;
    final action = change['action'] as String;
    final recordId = change['recordId'] as String;
    final dataStr = change['data'] as String?;

    if (domain == 'chatMessage') {
      if (action == 'delete') {
        await _chatService.deleteMessage(recordId);
        return;
      }
      if (dataStr == null) return;
      final data = jsonDecode(dataStr) as Map<String, dynamic>;
      final remoteMsg = ChatMessage.fromJson(data);
      final localMsg = _chatService.getMessage(recordId);
      if (localMsg != null) {
        if (remoteMsg.timestamp.millisecondsSinceEpoch <=
            localMsg.timestamp.millisecondsSinceEpoch) {
          return;
        }
      }
      var conv = _chatService.getConversation(remoteMsg.conversationId);
      if (conv == null) {
        await _chatService.ensureConversation(
          remoteMsg.conversationId,
          title: remoteMsg.conversationId,
          createdAt: remoteMsg.timestamp,
          updatedAt: remoteMsg.timestamp,
        );
      }
      await _chatService.addMessageDirectly(
        remoteMsg.conversationId,
        remoteMsg,
      );
    } else if (domain == 'conversation') {
      if (action == 'delete') {
        await _chatService.deleteConversation(recordId);
        return;
      }
      if (dataStr == null) return;
      final remoteConv = Conversation.fromJson(
        jsonDecode(dataStr) as Map<String, dynamic>,
      );
      final localConv = _chatService.getConversation(recordId);
      if (localConv != null) {
        if (remoteConv.updatedAt.millisecondsSinceEpoch <=
            localConv.updatedAt.millisecondsSinceEpoch) {
          return;
        }
        localConv.title = remoteConv.title;
        localConv.updatedAt = remoteConv.updatedAt;
        localConv.isPinned = remoteConv.isPinned;
        localConv.assistantId = remoteConv.assistantId;
        localConv.truncateIndex = remoteConv.truncateIndex;
        localConv.mcpServerIds = List.of(remoteConv.mcpServerIds);
        localConv.versionSelections = Map<String, int>.from(
          remoteConv.versionSelections,
        );
        localConv.summary = remoteConv.summary;
        localConv.save();
        _chatService.notifyDataChange();
      } else {
        await _chatService.createConversation(
          title: remoteConv.title,
          assistantId: remoteConv.assistantId,
        );
      }
    }
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _pullTimer?.cancel();
  }
}
