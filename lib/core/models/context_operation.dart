import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'chat_message.dart';

enum ContextOperationKind { clear, compress }

enum ContextHistorySource { effective, previous, original }

/// A history transformation, stored independently from actual chat messages.
/// Group ids locate ranges; revision ids and content fingerprints detect edits.
class ContextOperation {
  const ContextOperation({
    required this.id,
    required this.kind,
    required this.anchorGroupId,
    required this.appliedAfterGroupId,
    required this.sourceGroups,
    required this.dependencies,
    required this.createdAt,
    this.summary = '',
    this.originalSummary = '',
    this.revoked = false,
    this.keepUserMessages = 0,
    this.model = '',
    this.inputTokens = 0,
    this.inputMode = 'unlimited',
    this.inputMaxChars,
    this.historySource = ContextHistorySource.effective,
    this.includedEditedSummaries = true,
    this.includedAttachmentsAndTools = true,
    this.convertedFromLegacyClear = false,
    this.inputParts = 0,
  });

  static const entityKind = 'conversationContext';
  static const summaryPrefix = 'context-summary:';
  final String id;
  final ContextOperationKind kind;
  final String anchorGroupId;
  // A summary created after a retained tail must not leak into regeneration
  // of a message that predates the operation, even if its UI anchor is earlier.
  final String appliedAfterGroupId;
  final List<String> sourceGroups;
  final List<String> dependencies;
  final DateTime createdAt;
  final String summary;
  final String originalSummary;
  final bool revoked;
  final int keepUserMessages;
  final String model;
  final int inputTokens;
  final String inputMode;
  final int? inputMaxChars;
  final ContextHistorySource historySource;
  final bool includedEditedSummaries;
  final bool includedAttachmentsAndTools;
  final bool convertedFromLegacyClear;
  final int inputParts;

  bool get isEdited => summary != originalSummary;
  bool get isCompression => kind == ContextOperationKind.compress;
  String get summaryMessageId => '$summaryPrefix$id';
  static bool isSummary(ChatMessage message) =>
      message.id.startsWith(summaryPrefix);

  ContextOperation copyWith({String? summary, bool? revoked}) =>
      ContextOperation(
        id: id,
        kind: kind,
        anchorGroupId: anchorGroupId,
        appliedAfterGroupId: appliedAfterGroupId,
        sourceGroups: sourceGroups,
        dependencies: dependencies,
        createdAt: createdAt,
        summary: summary ?? this.summary,
        originalSummary: originalSummary,
        revoked: revoked ?? this.revoked,
        keepUserMessages: keepUserMessages,
        model: model,
        inputTokens: inputTokens,
        inputMode: inputMode,
        inputMaxChars: inputMaxChars,
        historySource: historySource,
        includedEditedSummaries: includedEditedSummaries,
        includedAttachmentsAndTools: includedAttachmentsAndTools,
        convertedFromLegacyClear: convertedFromLegacyClear,
        inputParts: inputParts,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'anchor': anchorGroupId,
    'appliedAfter': appliedAfterGroupId,
    'groups': sourceGroups,
    'dependencies': dependencies,
    'createdAt': createdAt.toIso8601String(),
    'summary': summary,
    'originalSummary': originalSummary,
    'revoked': revoked,
    'keep': keepUserMessages,
    'model': model,
    'inputTokens': inputTokens,
    'inputMode': inputMode,
    'inputMaxChars': inputMaxChars,
    'historySource': historySource.name,
    'includedEditedSummaries': includedEditedSummaries,
    'includedAttachmentsAndTools': includedAttachmentsAndTools,
    'convertedFromLegacyClear': convertedFromLegacyClear,
    'inputParts': inputParts,
  };

  factory ContextOperation.fromJson(Map<String, dynamic> json) =>
      ContextOperation(
        id: json['id'] as String,
        kind: ContextOperationKind.values.byName(json['kind'] as String),
        anchorGroupId: json['anchor'] as String,
        appliedAfterGroupId: json['appliedAfter'] as String,
        sourceGroups: List<String>.from(json['groups'] as List),
        dependencies: List<String>.from(json['dependencies'] as List),
        createdAt: DateTime.parse(json['createdAt'] as String),
        summary: json['summary'] as String,
        originalSummary: json['originalSummary'] as String,
        revoked: json['revoked'] as bool,
        keepUserMessages: json['keep'] as int,
        model: json['model'] as String,
        inputTokens: json['inputTokens'] as int,
        inputMode: json['inputMode'] as String,
        inputMaxChars: json['inputMaxChars'] as int?,
        historySource: ContextHistorySource.values.byName(
          json['historySource'] as String,
        ),
        includedEditedSummaries: json['includedEditedSummaries'] as bool,
        includedAttachmentsAndTools:
            json['includedAttachmentsAndTools'] != false,
        convertedFromLegacyClear: json['convertedFromLegacyClear'] == true,
        inputParts: json['inputParts'] as int? ?? 0,
      );

  ContextOperation remap({
    required Map<String, String> groups,
    required Map<String, String> operations,
  }) => ContextOperation(
    id: operations[id]!,
    kind: kind,
    anchorGroupId: groups[anchorGroupId]!,
    appliedAfterGroupId: groups[appliedAfterGroupId]!,
    sourceGroups: sourceGroups.map((id) => groups[id]!).toList(),
    dependencies: dependencies.map((id) => operations[id]!).toList(),
    createdAt: createdAt,
    summary: summary,
    originalSummary: originalSummary,
    revoked: revoked,
    keepUserMessages: keepUserMessages,
    model: model,
    inputTokens: inputTokens,
    inputMode: inputMode,
    inputMaxChars: inputMaxChars,
    historySource: historySource,
    includedEditedSummaries: includedEditedSummaries,
    includedAttachmentsAndTools: includedAttachmentsAndTools,
    convertedFromLegacyClear: convertedFromLegacyClear,
    inputParts: inputParts,
  );
}

/// Pure projection shared by sending, compression previews and regeneration.
class ContextHistory {
  static String operationsFingerprint(List<ContextOperation> operations) =>
      sha256
          .convert(
            utf8.encode(
              jsonEncode(operations.map((op) => op.toJson()).toList()),
            ),
          )
          .toString();

  static String group(ChatMessage message) => message.groupId ?? message.id;

  static Set<String> affectedOperations(
    List<ContextOperation> operations, {
    Set<String> operationIds = const {},
    Set<String> changedGroups = const {},
    Set<String> removedGroups = const {},
  }) {
    final affected = <String>{...operationIds};
    for (final operation in operations) {
      if (operation.revoked) continue;
      if ((operation.isCompression &&
              operation.sourceGroups.any(changedGroups.contains)) ||
          removedGroups.contains(operation.anchorGroupId) ||
          removedGroups.contains(operation.appliedAfterGroupId) ||
          operation.dependencies.any(affected.contains)) {
        affected.add(operation.id);
      }
    }
    return affected;
  }

  static List<ChatMessage> resolve(
    List<ChatMessage> selected,
    List<ContextOperation> operations, {
    int? limit,
    String? throughGroupId,
    String? endGroupId,
    Set<String> omitOperations = const {},
  }) {
    final positions = {
      for (var i = 0; i < selected.length; i++) group(selected[i]): i,
    };
    final through = throughGroupId == null
        ? selected.length
        : positions[throughGroupId];
    if (through == null) return [];
    final end = endGroupId == null ? through : positions[endGroupId];
    if (end == null) return [];
    var result = selected
        .where((message) => positions[group(message)]! <= end)
        .toList();
    final summaryPositions = <String, int>{};
    for (final operation in operations) {
      if (operation.revoked || omitOperations.contains(operation.id)) continue;
      final anchor = positions[operation.anchorGroupId];
      final appliedAfter = positions[operation.appliedAfterGroupId];
      // Missing references fail closed. They must be revoked in the same
      // transaction as deletion, never silently activate previously cleared data.
      if (anchor == null || appliedAfter == null) {
        throw StateError('context_boundary_missing');
      }
      if (throughGroupId != null && appliedAfter >= through) continue;
      if (!operation.isCompression) {
        result.removeWhere(
          (message) =>
              (summaryPositions[message.id] ?? positions[group(message)]!) <=
              anchor,
        );
        continue;
      }
      final groups = operation.sourceGroups.toSet();
      final dependencyMessages = operation.dependencies
          .map((id) => '${ContextOperation.summaryPrefix}$id')
          .toSet();
      // A later independent clear may hide an older summary. Applying nodes
      // in creation order preserves that boundary without inventing dependencies.
      result.removeWhere(
        (message) =>
            groups.contains(group(message)) ||
            dependencyMessages.contains(message.id),
      );
      summaryPositions[operation.summaryMessageId] = anchor;
      final insertion = result.indexWhere(
        (message) =>
            (summaryPositions[message.id] ?? positions[group(message)]!) >
            anchor,
      );
      result.insert(
        insertion < 0 ? result.length : insertion,
        ChatMessage(
          id: operation.summaryMessageId,
          role: 'user',
          content: operation.summary,
          conversationId: selected.first.conversationId,
          timestamp: operation.createdAt,
        ),
      );
    }
    if (limit != null) {
      final raw = result.where((m) => !ContextOperation.isSummary(m)).toList();
      final retained = raw
          .skip((raw.length - limit).clamp(0, raw.length))
          .map((m) => m.id)
          .toSet();
      result = result
          .where(
            (m) => ContextOperation.isSummary(m) || retained.contains(m.id),
          )
          .toList();
    }
    return result;
  }

  static List<ChatMessage> compressionInput(
    List<ChatMessage> selected,
    List<ContextOperation> operations, {
    required ContextHistorySource source,
    bool includeEditedSummaries = true,
  }) {
    if (source == ContextHistorySource.effective) {
      return resolve(selected, operations);
    }
    final effective = resolve(selected, operations);
    final visibleIds = effective
        .where(ContextOperation.isSummary)
        .map((m) => m.id.substring(ContextOperation.summaryPrefix.length))
        .toSet();
    final expanded = <String>{...visibleIds};
    if (source == ContextHistorySource.original) {
      void include(String id) {
        final op = operations.firstWhere((op) => op.id == id);
        for (final dependency in op.dependencies) {
          if (expanded.add(dependency)) include(dependency);
        }
      }

      for (final id in visibleIds) {
        include(id);
      }
    }
    final result = resolve(selected, operations, omitOperations: expanded);
    if (includeEditedSummaries) {
      for (final op in operations) {
        if (expanded.contains(op.id) && !op.revoked && op.isEdited) {
          result.insert(
            0,
            ChatMessage(
              id: 'context-note:${op.id}',
              role: 'user',
              content: '[User-edited history summary]\n${op.summary}',
              conversationId: selected.first.conversationId,
            ),
          );
        }
      }
    }
    return result;
  }

  static String fingerprint(
    List<ChatMessage> selected,
    List<ContextOperation> operations,
  ) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'messages': [
              for (final m in selected)
                {
                  'id': m.id,
                  'group': group(m),
                  'version': m.version,
                  'parts': m.parts
                      .map((p) => [p.kind, p.encodePayload()])
                      .toList(),
                },
            ],
            'operations': operations.map((op) => op.toJson()).toList(),
          }),
        ),
      )
      .toString();
}
