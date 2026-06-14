import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

enum SyncDomain { chatMessage, conversation, toolEvent, thoughtSig }

enum SyncAction { create, update, delete }

class SyncChangeLogEntry {
  final String id;
  final String domain;
  final String action;
  final String recordId;
  final int timestampMillis;
  final String? data;
  final String deviceId;
  final String? batchId;
  final bool synced;

  const SyncChangeLogEntry({
    required this.id,
    required this.domain,
    required this.action,
    required this.recordId,
    required this.timestampMillis,
    this.data,
    required this.deviceId,
    this.batchId,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'domain': domain,
    'action': action,
    'recordId': recordId,
    'timestampMillis': timestampMillis,
    'data': data,
    'deviceId': deviceId,
    'batchId': batchId,
    'synced': synced,
  };

  factory SyncChangeLogEntry.fromJson(Map<String, dynamic> json) =>
      SyncChangeLogEntry(
        id: json['id'] as String,
        domain: json['domain'] as String,
        action: json['action'] as String,
        recordId: json['recordId'] as String,
        timestampMillis: json['timestampMillis'] as int,
        data: json['data'] as String?,
        deviceId: json['deviceId'] as String,
        batchId: json['batchId'] as String?,
        synced: json['synced'] as bool? ?? false,
      );
}

class SyncChangeLog {
  static const String _boxName = 'sync_change_log_v1';

  Box? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  String append({
    required String domain,
    required String action,
    required String recordId,
    int? timestampMillis,
    String? data,
    required String deviceId,
  }) {
    final id = const Uuid().v4();
    final entry = SyncChangeLogEntry(
      id: id,
      domain: domain,
      action: action,
      recordId: recordId,
      timestampMillis: timestampMillis ?? DateTime.now().millisecondsSinceEpoch,
      data: data,
      deviceId: deviceId,
    );
    _box!.put(id, entry.toJson());
    return id;
  }

  List<SyncChangeLogEntry> getUnsynced() {
    final entries = <SyncChangeLogEntry>[];
    for (final value in _box!.values) {
      final map = Map<String, dynamic>.from(value as Map);
      final entry = SyncChangeLogEntry.fromJson(map);
      if (!entry.synced && entry.batchId == null) {
        entries.add(entry);
      }
    }
    return entries;
  }

  void markBatch(List<SyncChangeLogEntry> entries, String batchId) {
    for (final entry in entries) {
      final map = Map<String, dynamic>.from(_box!.get(entry.id) as Map);
      map['batchId'] = batchId;
      _box!.put(entry.id, map);
    }
  }

  void deleteByBatchId(String batchId) {
    final keysToDelete = <dynamic>[];
    for (final key in _box!.keys) {
      final map = Map<String, dynamic>.from(_box!.get(key) as Map);
      if (map['batchId'] == batchId) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      _box!.delete(key);
    }
  }

  void deleteSynced() {
    final keysToDelete = <dynamic>[];
    for (final key in _box!.keys) {
      final map = Map<String, dynamic>.from(_box!.get(key) as Map);
      if (map['synced'] == true) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      _box!.delete(key);
    }
  }

  int get pendingCount {
    var count = 0;
    for (final value in _box!.values) {
      final map = Map<String, dynamic>.from(value as Map);
      if (map['synced'] == false && map['batchId'] == null) {
        count++;
      }
    }
    return count;
  }
}
