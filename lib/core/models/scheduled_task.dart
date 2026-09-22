enum ScheduledTaskMode { newChat, followUp, regenerate }

enum ScheduledTaskContextPolicy { latest, snapshot }

enum ScheduledTaskUnavailablePolicy { remind, skip }

enum ScheduledTaskRepeat { once, daily, weekdays, custom }

class ScheduledTask {
  static const defaultPreparationWindowMinutes = Duration.minutesPerDay;
  static const defaultPreparationPrompt =
      'The next user instruction is a scheduled message for this conversation. '
      'Write the assistant message exactly as the user should receive it, '
      'in the established language, tone and persona. Continue the conversation naturally. '
      'Output only the message itself: no preface, execution report, or explanation '
      'that this is scheduled, prepared in advance, or a text response.\n\n'
      'The intended delivery time is {{scheduled_time}} (UTC offset {{utc_offset}}); '
      'this is internal context, not text to repeat unless the user explicitly asks for it. '
      'Use only the supplied context. Tools and live information are unavailable; '
      'do not claim to have performed external actions.';

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
    this.allowPreparation = false,
    this.preparationPrompt = defaultPreparationPrompt,
    this.contextPolicy = ScheduledTaskContextPolicy.latest,
    this.unavailablePolicy = ScheduledTaskUnavailablePolicy.skip,
    this.notify = true,
    this.showPreview = true,
    this.preparationWindowMinutes = defaultPreparationWindowMinutes,
    this.maxPrepareAttempts = 2,
    this.preparationCooldownMinutes = 10,
    this.revision = 0,
    this.scheduleRevision = 0,
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
  final bool allowPreparation, notify, showPreview;
  final String preparationPrompt;
  final ScheduledTaskContextPolicy contextPolicy;
  final ScheduledTaskUnavailablePolicy unavailablePolicy;
  final int preparationWindowMinutes,
      maxPrepareAttempts,
      preparationCooldownMinutes,
      revision,
      scheduleRevision;

  bool get canPrepare =>
      allowPreparation && mode != ScheduledTaskMode.regenerate;

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

  ScheduledTask withState({
    required DateTime? nextRunAt,
    bool? enabled,
    bool? exhausted,
    List<ScheduledTaskRun>? runs,
    int? revision,
    int? scheduleRevision,
  }) => ScheduledTask(
    id: id,
    name: name,
    prompt: prompt,
    assistantId: assistantId,
    hour: hour,
    minute: minute,
    weekdays: weekdays,
    enabled: enabled ?? this.enabled,
    nextRunAt: nextRunAt,
    exhausted: exhausted ?? this.exhausted,
    runs: runs ?? this.runs,
    mode: mode,
    conversationId: conversationId,
    messageId: messageId,
    modelProvider: modelProvider,
    modelId: modelId,
    onceDate: onceDate,
    startDate: startDate,
    endDate: endDate,
    allowPreparation: allowPreparation,
    preparationPrompt: preparationPrompt,
    contextPolicy: contextPolicy,
    unavailablePolicy: unavailablePolicy,
    notify: notify,
    showPreview: showPreview,
    preparationWindowMinutes: preparationWindowMinutes,
    maxPrepareAttempts: maxPrepareAttempts,
    preparationCooldownMinutes: preparationCooldownMinutes,
    revision: revision ?? this.revision,
    scheduleRevision: scheduleRevision ?? this.scheduleRevision,
  );

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
    allowPreparation: json['allowPreparation'] == true,
    preparationPrompt:
        json['preparationPrompt'] as String? ?? defaultPreparationPrompt,
    contextPolicy: ScheduledTaskContextPolicy.values.byName(
      json['contextPolicy'] as String? ?? 'latest',
    ),
    unavailablePolicy: ScheduledTaskUnavailablePolicy.values.byName(
      json['unavailablePolicy'] as String? ?? 'skip',
    ),
    notify: json['notify'] != false,
    showPreview: json['showPreview'] != false,
    preparationWindowMinutes:
        (json['preparationWindowMinutes'] as int? ??
                defaultPreparationWindowMinutes)
            .clamp(1, 1440),
    maxPrepareAttempts: (json['maxPrepareAttempts'] as int? ?? 2).clamp(1, 5),
    preparationCooldownMinutes:
        (json['preparationCooldownMinutes'] as int? ?? 10).clamp(1, 1440),
    revision: json['revision'] as int? ?? 0,
    scheduleRevision: json['scheduleRevision'] as int? ?? 0,
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
    'allowPreparation': allowPreparation,
    'preparationPrompt': preparationPrompt,
    'contextPolicy': contextPolicy.name,
    'unavailablePolicy': unavailablePolicy.name,
    'notify': notify,
    'showPreview': showPreview,
    'preparationWindowMinutes': preparationWindowMinutes,
    'maxPrepareAttempts': maxPrepareAttempts,
    'preparationCooldownMinutes': preparationCooldownMinutes,
    'revision': revision,
    'scheduleRevision': scheduleRevision,
  };

  Map<String, dynamic> toStoredJson() => {
    ...toJson(),
    'nextRunAt': nextRunAt?.millisecondsSinceEpoch,
    'exhausted': exhausted,
    'runs': runs.map((run) => run.toJson()).toList(),
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
    this.startedAt,
    required this.status,
    this.conversationId,
    this.preview,
    this.error,
    this.scheduledFor,
    this.preparedAt,
    this.lastPrepareAt,
    this.taskRevision = 0,
    this.contextRevision,
    this.payloadId,
    this.prepareAttempts = 0,
    this.notificationState = 'none',
  });
  final String id, status;
  final DateTime? startedAt, scheduledFor, preparedAt, lastPrepareAt;
  final String? conversationId, preview, error, contextRevision, payloadId;
  final int taskRevision, prepareAttempts;
  final String notificationState;

  bool get awaitingPublication =>
      const {'pending', 'preparing', 'prepared', 'publishing'}.contains(status);
  DateTime get displayTime => scheduledFor ?? startedAt!;

  ScheduledTaskRun update(Map<String, Object?> changes) =>
      ScheduledTaskRun.fromJson({...toJson(), ...changes});

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt?.millisecondsSinceEpoch,
    'status': status,
    'conversationId': conversationId,
    'preview': preview,
    'error': error,
    'scheduledFor': scheduledFor?.millisecondsSinceEpoch,
    'preparedAt': preparedAt?.millisecondsSinceEpoch,
    'lastPrepareAt': lastPrepareAt?.millisecondsSinceEpoch,
    'taskRevision': taskRevision,
    'contextRevision': contextRevision,
    'payloadId': payloadId,
    'prepareAttempts': prepareAttempts,
    'notificationState': notificationState,
  };

  factory ScheduledTaskRun.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json[key] as int);
    return ScheduledTaskRun(
      id: json['id'] as String,
      startedAt: date('startedAt'),
      status: json['status'] as String,
      conversationId: json['conversationId'] as String?,
      preview: json['preview'] as String?,
      error: json['error'] as String?,
      scheduledFor: date('scheduledFor'),
      preparedAt: date('preparedAt'),
      lastPrepareAt: date('lastPrepareAt'),
      taskRevision: json['taskRevision'] as int? ?? 0,
      contextRevision: json['contextRevision'] as String?,
      payloadId: json['payloadId'] as String?,
      prepareAttempts: json['prepareAttempts'] as int? ?? 0,
      notificationState: json['notificationState'] as String? ?? 'none',
    );
  }
}
