import 'dart:convert';

import '../../models/assistant.dart';
import '../../utils/multimodal_input_utils.dart';
import '../logging/context_log_models.dart';

/// Request metadata, sampled once after attachment processing. Never frozen
/// into a message or sampled again by HTTP retries / client tool follow-ups.
class RuntimeContextSnapshot {
  const RuntimeContextSnapshot({
    required this.capturedAt,
    this.localTime,
    this.timezoneName,
    this.utcOffset,
    this.appLocale,
    this.modelName,
    this.modelId,
  });

  factory RuntimeContextSnapshot.capture({
    required Assistant? assistant,
    required DateTime now,
    required String appLocale,
    required String modelName,
    required String modelId,
    String? timezoneName,
    Duration? utcOffset,
  }) {
    final includeTime = assistant?.appendCurrentTimeToUserMessage ?? false;
    return RuntimeContextSnapshot(
      capturedAt: now,
      localTime: includeTime ? now : null,
      timezoneName: includeTime ? timezoneName ?? now.timeZoneName : null,
      utcOffset: includeTime ? utcOffset ?? now.timeZoneOffset : null,
      appLocale: assistant?.includeAppLocaleInContext == true
          ? appLocale
          : null,
      modelName: assistant?.includeModelInfoInContext == true
          ? modelName
          : null,
      modelId: assistant?.includeModelInfoInContext == true ? modelId : null,
    );
  }

  final DateTime capturedAt;
  final DateTime? localTime;
  final String? timezoneName;
  final Duration? utcOffset;
  final String? appLocale;
  final String? modelName;
  final String? modelId;

  static String formatOffset(Duration offset) {
    final minutes = offset.inMinutes.abs();
    return '${offset.isNegative ? '-' : '+'}'
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }

  String? get formattedTime {
    final time = localTime;
    if (time == null) return null;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year.toString().padLeft(4, '0')}-${two(time.month)}-'
        '${two(time.day)}T${two(time.hour)}:${two(time.minute)}:'
        '${two(time.second)}${formatOffset(utcOffset ?? time.timeZoneOffset)}';
  }

  String? get weekday => localTime == null
      ? null
      : const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ][localTime!.weekday - 1];

  Map<String, Object> get values => {
    if (formattedTime != null) 'generation_time': formattedTime!,
    if (weekday != null) 'weekday': weekday!,
    if (timezoneName?.isNotEmpty == true) 'timezone': timezoneName!,
    if (appLocale != null) 'app_locale': appLocale!,
    if (modelName != null) 'configured_model_name': modelName!,
    if (modelId != null) 'request_model_id': modelId!,
  };

  String toPrompt() {
    final fields = values;
    if (fields.isEmpty) return '';
    // Configured names remain data even if they contain markup.
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(fields).replaceAll('<', r'\u003c').replaceAll('>', r'\u003e');
    return [
      '<runtime_context>',
      'Request metadata supplied by Kelivo, not user-authored text.',
      if (localTime != null)
        'generation_time is the time sampled for this generation. Times in '
            'earlier messages are historical; this is not a continuously updated clock.',
      if (appLocale != null)
        'app_locale describes the app UI, not a mandatory response language.',
      if (modelId != null || modelName != null)
        'Model fields describe the configured request target, not verified server identity.',
      json,
      '</runtime_context>',
    ].join('\n');
  }
}

/// Appends only to request-owned maps, after templates / freezing / trimming.
/// The provenance tags make this idempotent without inspecting user text.
void injectRuntimeContext(
  List<Map<String, dynamic>> messages,
  RuntimeContextSnapshot snapshot,
) {
  final text = snapshot.toPrompt();
  if (text.isEmpty ||
      messages.any(
        (message) => ContextSegmentTags.read(
          message,
        ).any((tag) => tag['source'] == ContextSource.runtimeContext.name),
      )) {
    return;
  }
  final index = messages.lastIndexWhere(
    (message) =>
        message['role'] == 'user' &&
        (message[multimodalInternalRevisionIdKey] ?? '').toString().isNotEmpty,
  );
  final Map<String, dynamic> target;
  if (index < 0) {
    target = {'role': 'user', 'content': ''};
    messages.add(target);
  } else {
    target = messages[index];
  }
  final original = target['content'];
  final previousLength = extractApiMessageText(original).length;
  if (ContextSegmentTags.read(target).isEmpty && previousLength > 0) {
    ContextSegmentTags.replaceWithSingle(
      target,
      source: ContextSource.chatHistory,
      length: previousLength,
    );
  }
  final tags = ContextSegmentTags.read(target);
  if (tags.isNotEmpty) {
    // Attachment inlining can change the last text segment after it was tagged.
    final prefixLength = tags
        .take(tags.length - 1)
        .fold<int>(
          0,
          (sum, tag) => sum + ((tag['length'] as num?)?.toInt() ?? 0),
        );
    tags.last['length'] = (previousLength - prefixLength).clamp(
      0,
      previousLength,
    );
    ContextSegmentTags.write(target, tags);
  }
  final suffix = '${previousLength > 0 ? '\n\n' : ''}$text';
  target['content'] = original is List
      ? [
          ...original,
          {'type': 'text', 'text': suffix},
        ]
      : '${original ?? ''}$suffix';
  ContextSegmentTags.append(
    target,
    source: ContextSource.runtimeContext,
    length: suffix.length,
  );
}

/// Only dynamic clock placeholders affect the duplicate-time hint.
List<String> detectTimeVariablesInSystemPrompt(String prompt) => [
  for (final token in const ['{cur_date}', '{cur_time}', '{cur_datetime}'])
    if (prompt.contains(token)) token,
];
