class ScheduledTask {
  const ScheduledTask({
    required this.id,
    required this.name,
    required this.prompt,
    required this.assistantId,
    required this.hour,
    required this.minute,
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.enabled = true,
    this.nextRunAt,
    this.runs = const [],
  });

  final String id, name, prompt, assistantId;
  final int hour, minute;
  final List<int> weekdays;
  final bool enabled;
  final DateTime? nextRunAt;
  final List<ScheduledTaskRun> runs;
  bool get running => runs.any((run) => run.status == 'running');
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  factory ScheduledTask.fromJson(Map<String, dynamic> json) => ScheduledTask(
    id: json['id'] as String,
    name: json['name'] as String,
    prompt: json['prompt'] as String,
    assistantId: json['assistantId'] as String,
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    weekdays: (json['weekdays'] as List).cast<int>(),
    enabled: json['enabled'] as bool,
    nextRunAt: json['nextRunAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json['nextRunAt'] as int),
    runs: (json['runs'] as List? ?? [])
        .map(
          (r) => ScheduledTaskRun.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList(),
  );

  Map<String, dynamic> toJson({bool? enabled}) => {
    'id': id,
    'name': name,
    'prompt': prompt,
    'assistantId': assistantId,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays,
    'enabled': enabled ?? this.enabled,
  };
}

class ScheduledTaskRun {
  const ScheduledTaskRun({
    required this.id,
    required this.startedAt,
    required this.status,
    this.conversationId,
    this.preview,
    this.error,
  });
  final String id, status;
  final DateTime startedAt;
  final String? conversationId, preview, error;
  factory ScheduledTaskRun.fromJson(Map<String, dynamic> json) =>
      ScheduledTaskRun(
        id: json['id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          json['startedAt'] as int,
        ),
        status: json['status'] as String,
        conversationId: json['conversationId'] as String?,
        preview: json['preview'] as String?,
        error: json['error'] as String?,
      );
}
