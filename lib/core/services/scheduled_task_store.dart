import '../models/scheduled_task.dart';
import 'json_blob_store.dart';

/// Device-bound task definitions and history in the application's SQLite store.
class ScheduledTaskStore extends JsonBlobStore<ScheduledTask> {
  ScheduledTaskStore(super.preferences);

  static const preferenceKey = 'desktop_scheduled_tasks_v1';
  @override
  String get storageKey => preferenceKey;
  @override
  ScheduledTask decodeItem(Map<String, dynamic> json) =>
      ScheduledTask.fromJson(json);
  @override
  Map<String, dynamic> encodeItem(ScheduledTask item) => item.toStoredJson();
}
