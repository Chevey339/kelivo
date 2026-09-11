enum ScheduledTaskMode { newChat, followUp, regenerate }

enum ScheduledTaskRepeat { once, daily, weekdays, custom }

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
    this.mode = ScheduledTaskMode.newChat,
    this.conversationId,
    this.messageId,
    this.modelProvider,
    this.modelId,
    this.onceDate,
    this.startDate,
    this.endDate,
    this.exhausted = false,
  });

  final String id, name, prompt, assistantId;
  final int hour, minute;
  final List<int> weekdays;
  final bool enabled;
  final DateTime? nextRunAt;
  final List<ScheduledTaskRun> runs;
  final ScheduledTaskMode mode;
  final String? conversationId, messageId, modelProvider, modelId;
  final DateTime? onceDate, startDate, endDate;
  final bool exhausted;
  ScheduledTaskRepeat get repeat {
    if (onceDate != null) return ScheduledTaskRepeat.once;
    final days = weekdays.toSet();
    if (days.length == 7) return ScheduledTaskRepeat.daily;
    if (days.length == 5 && days.every((day) => day <= 5)) {
      return ScheduledTaskRepeat.weekdays;
    }
    return ScheduledTaskRepeat.custom;
  }

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
    mode: ScheduledTaskMode.values.byName(json['mode'] as String? ?? 'newChat'),
    conversationId: json['conversationId'] as String?,
    messageId: json['messageId'] as String?,
    modelProvider: json['modelProvider'] as String?,
    modelId: json['modelId'] as String?,
    onceDate: _parseDate(json['onceDate']),
    startDate: _parseDate(json['startDate']),
    endDate: _parseDate(json['endDate']),
    exhausted: json['exhausted'] == true,
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
    'mode': mode.name,
    'conversationId': conversationId,
    'messageId': messageId,
    'modelProvider': modelProvider,
    'modelId': modelId,
    'onceDate': dateKey(onceDate),
    'startDate': dateKey(startDate),
    'endDate': dateKey(endDate),
  };

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  /// Calendar dates deliberately have no offset: tasks follow device local time.
  static String? dateKey(DateTime? date) => date == null
      ? null
      : '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
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
