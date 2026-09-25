import 'dart:convert';

import '../models/scheduled_task.dart';
import '../models/scheduled_task_payload.dart';
import 'json_blob_store.dart';

/// Device-bound task definitions and history in the application's SQLite store.
class ScheduledTaskStore extends JsonBlobStore<ScheduledTask> {
  ScheduledTaskStore(super.preferences);

  static const resultsKey = 'scheduled_task_results_v1';

  Future<Map<String, dynamic>> readResults() async {
    await preferences.load();
    final raw = preferences.getString(resultsKey);
    if (raw == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> writeResults(Map<String, dynamic> results) =>
      preferences.setString(resultsKey, jsonEncode(results));

  ScheduledTaskPayload? payload(Map<String, dynamic> results, String id) {
    final raw = (results['payloads'] as Map?)?[id];
    return raw == null
        ? null
        : ScheduledTaskPayload.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  static const preferenceKey = 'desktop_scheduled_tasks_v1';
  @override
  String get storageKey => preferenceKey;
  @override
  ScheduledTask decodeItem(Map<String, dynamic> json) =>
      ScheduledTask.fromJson(json);
  @override
  Map<String, dynamic> encodeItem(ScheduledTask item) => item.toStoredJson();
}
