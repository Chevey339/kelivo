import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';

final class LegacyOrderedMessage {
  const LegacyOrderedMessage({required this.message, required this.order});

  final ChatMessage message;
  final int order;
}

final class LegacyGraphIssue {
  const LegacyGraphIssue({
    required this.kind,
    required this.severity,
    required this.sourceEntityId,
    required this.details,
  });

  final String kind;
  final String severity;
  final String? sourceEntityId;
  final Map<String, Object?> details;
}

final class LegacyGraphPart {
  const LegacyGraphPart({
    required this.ordinal,
    required this.kind,
    required this.payload,
  });

  final int ordinal;
  final String kind;
  final String payload;
}

final class LegacyGraphRevision {
  const LegacyGraphRevision({
    required this.id,
    required this.slotId,
    required this.parentRevisionId,
    required this.revisionNo,
    required this.createdAt,
    required this.updatedAt,
    required this.finalizedAt,
    required this.parts,
  });

  final String id;
  final String slotId;
  final String? parentRevisionId;
  final int revisionNo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalizedAt;
  final List<LegacyGraphPart> parts;
}

final class LegacyGraphSlot {
  const LegacyGraphSlot({
    required this.id,
    required this.groupKey,
    required this.role,
    required this.createdAt,
    required this.revisions,
    required this.selectedRevisionId,
  });

  final String id;
  final String groupKey;
  final String role;
  final DateTime createdAt;
  final List<LegacyGraphRevision> revisions;
  final String selectedRevisionId;
}

final class LegacyMessageGraphProjection {
  const LegacyMessageGraphProjection({
    required this.conversationId,
    required this.branchId,
    required this.causalityKind,
    required this.slots,
    required this.activeRevisionIds,
    required this.contextStartRevisionId,
    required this.issues,
  });

  final String conversationId;
  final String branchId;
  final String causalityKind;
  final List<LegacyGraphSlot> slots;
  final List<String> activeRevisionIds;
  final String? contextStartRevisionId;
  final List<LegacyGraphIssue> issues;
}

/// Deterministically converts the legacy flat message/version representation.
///
/// The result is explicitly a visible legacy projection, never native history.
final class LegacyMessageGraphAdapter {
  const LegacyMessageGraphAdapter();

  LegacyMessageGraphProjection adaptRecoveredOrphans({
    required String recoveredConversationId,
    required List<LegacyOrderedMessage> orphanMessages,
  }) {
    final conversation = Conversation(
      id: recoveredConversationId,
      title: 'Recovered',
      messageIds: orphanMessages.map((entry) => entry.message.id).toList(),
    );
    final normalized = [
      for (final entry in orphanMessages)
        LegacyOrderedMessage(
          message: entry.message.copyWith(
            conversationId: recoveredConversationId,
            groupId: entry.message.groupId ?? entry.message.id,
          ),
          order: entry.order,
        ),
    ];
    final graph = adapt(conversation: conversation, messages: normalized);
    return LegacyMessageGraphProjection(
      conversationId: graph.conversationId,
      branchId: graph.branchId,
      causalityKind: 'legacy_ambiguous',
      slots: graph.slots,
      activeRevisionIds: graph.activeRevisionIds,
      contextStartRevisionId: graph.contextStartRevisionId,
      issues: [
        for (final entry in orphanMessages)
          LegacyGraphIssue(
            kind: 'orphan_message',
            severity: 'recovered',
            sourceEntityId: entry.message.id,
            details: const {'destination': 'recovered_conversation'},
          ),
        ...graph.issues,
      ],
    );
  }

  LegacyMessageGraphProjection adapt({
    required Conversation conversation,
    required List<LegacyOrderedMessage> messages,
  }) {
    final issues = <LegacyGraphIssue>[];
    final accepted = <LegacyOrderedMessage>[];
    final seenIds = <String>{};
    final seenOrders = <int>{};
    for (final candidate in messages) {
      final message = candidate.message;
      if (message.conversationId != conversation.id) {
        issues.add(
          LegacyGraphIssue(
            kind: 'orphan_message',
            severity: 'rejected',
            sourceEntityId: message.id,
            details: const {'reason': 'conversation_mismatch'},
          ),
        );
        continue;
      }
      if (!seenIds.add(message.id)) {
        issues.add(
          LegacyGraphIssue(
            kind: 'duplicate_id',
            severity: 'rejected',
            sourceEntityId: message.id,
            details: const {},
          ),
        );
        continue;
      }
      if (!seenOrders.add(candidate.order)) {
        issues.add(
          LegacyGraphIssue(
            kind: 'duplicate_order',
            severity: 'warning',
            sourceEntityId: message.id,
            details: {'order': candidate.order},
          ),
        );
      }
      accepted.add(candidate);
    }
    accepted.sort(_compareOrderedMessages);

    final grouped = <String, List<LegacyOrderedMessage>>{};
    for (final candidate in accepted) {
      final key = candidate.message.groupId ?? candidate.message.id;
      grouped.putIfAbsent(key, () => []).add(candidate);
    }
    final groups = grouped.entries.toList()
      ..sort((a, b) => _compareGroups(a.value, b.value));

    final slots = <LegacyGraphSlot>[];
    final activeRevisionIds = <String>[];
    String? parentRevisionId;
    var ambiguous = false;
    for (final group in groups) {
      final revisions = group.value.toList()
        ..sort((a, b) {
          final version = a.message.version.compareTo(b.message.version);
          if (version != 0) return version;
          final time = a.message.timestamp.compareTo(b.message.timestamp);
          if (time != 0) return time;
          return a.message.id.compareTo(b.message.id);
        });
      final versions = <int>{};
      for (final revision in revisions) {
        if (!versions.add(revision.message.version)) {
          ambiguous = true;
          issues.add(
            LegacyGraphIssue(
              kind: 'duplicate_version',
              severity: 'warning',
              sourceEntityId: revision.message.id,
              details: {
                'group': group.key,
                'version': revision.message.version,
              },
            ),
          );
        }
      }
      final selection = _resolveSelection(
        groupKey: group.key,
        revisions: revisions,
        rawSelection: conversation.versionSelections[group.key],
        issues: issues,
      );
      ambiguous = ambiguous || selection.ambiguous;
      final slotId = _stableId('slot', conversation.id, group.key);
      final graphRevisions = <LegacyGraphRevision>[];
      final allocatedRevisionNos = <int>{};
      for (final candidate in revisions) {
        final message = candidate.message;
        var revisionNo = message.version;
        while (!allocatedRevisionNos.add(revisionNo)) {
          revisionNo += 1;
        }
        final parts = <LegacyGraphPart>[];
        if (message.reasoningText?.isNotEmpty == true) {
          parts.add(
            LegacyGraphPart(
              ordinal: parts.length,
              kind: 'reasoning',
              payload: message.reasoningText!,
            ),
          );
        }
        parts.add(
          LegacyGraphPart(
            ordinal: parts.length,
            kind: 'text',
            payload: message.content,
          ),
        );
        graphRevisions.add(
          LegacyGraphRevision(
            id: message.id,
            slotId: slotId,
            parentRevisionId: parentRevisionId,
            revisionNo: revisionNo,
            createdAt: message.timestamp,
            updatedAt: message.timestamp,
            finalizedAt: message.isStreaming ? null : message.timestamp,
            parts: parts,
          ),
        );
      }
      final selected = selection.message;
      slots.add(
        LegacyGraphSlot(
          id: slotId,
          groupKey: group.key,
          role: selected.role,
          createdAt: group.value.first.message.timestamp,
          revisions: graphRevisions,
          selectedRevisionId: selected.id,
        ),
      );
      activeRevisionIds.add(selected.id);
      parentRevisionId = selected.id;
    }

    final boundary = _resolveBoundary(
      conversation: conversation,
      groups: groups,
      slots: slots,
      issues: issues,
    );
    return LegacyMessageGraphProjection(
      conversationId: conversation.id,
      branchId: _stableId('branch', conversation.id, 'legacy-main'),
      causalityKind: ambiguous
          ? 'legacy_ambiguous'
          : 'legacy_visible_projection',
      slots: List.unmodifiable(slots),
      activeRevisionIds: List.unmodifiable(activeRevisionIds),
      contextStartRevisionId: boundary,
      issues: List.unmodifiable(issues),
    );
  }

  _Selection _resolveSelection({
    required String groupKey,
    required List<LegacyOrderedMessage> revisions,
    required int? rawSelection,
    required List<LegacyGraphIssue> issues,
  }) {
    if (rawSelection == null) {
      return _Selection(message: revisions.last.message, ambiguous: false);
    }
    final ordinal = rawSelection >= 0 && rawSelection < revisions.length
        ? revisions[rawSelection].message
        : null;
    final byVersion = revisions
        .where((candidate) => candidate.message.version == rawSelection)
        .map((candidate) => candidate.message)
        .toList(growable: false);
    final version = byVersion.length == 1 ? byVersion.single : null;
    if (ordinal != null && version != null && ordinal.id != version.id) {
      issues.add(
        LegacyGraphIssue(
          kind: 'selection_ambiguous',
          severity: 'warning',
          sourceEntityId: groupKey,
          details: {
            'raw': rawSelection,
            'ordinalCandidate': ordinal.id,
            'versionCandidate': version.id,
          },
        ),
      );
      return _Selection(message: ordinal, ambiguous: true);
    }
    final resolved = ordinal ?? version;
    if (resolved != null) {
      return _Selection(message: resolved, ambiguous: false);
    }
    issues.add(
      LegacyGraphIssue(
        kind: 'selection_invalid',
        severity: 'recovered',
        sourceEntityId: groupKey,
        details: {'raw': rawSelection, 'fallback': revisions.last.message.id},
      ),
    );
    return _Selection(message: revisions.last.message, ambiguous: true);
  }

  String? _resolveBoundary({
    required Conversation conversation,
    required List<MapEntry<String, List<LegacyOrderedMessage>>> groups,
    required List<LegacyGraphSlot> slots,
    required List<LegacyGraphIssue> issues,
  }) {
    final truncateIndex = conversation.truncateIndex;
    if (truncateIndex < 0 || slots.isEmpty) return null;
    for (var index = 0; index < groups.length; index++) {
      final orders = groups[index].value.map((entry) => entry.order).toList();
      final minOrder = orders.reduce((a, b) => a < b ? a : b);
      final maxOrder = orders.reduce((a, b) => a > b ? a : b);
      if (truncateIndex >= minOrder && truncateIndex <= maxOrder) {
        if (truncateIndex != minOrder) {
          issues.add(
            LegacyGraphIssue(
              kind: 'truncate_inside_slot',
              severity: 'warning',
              sourceEntityId: groups[index].key,
              details: {'truncateIndex': truncateIndex, 'slotAnchor': minOrder},
            ),
          );
        }
        return slots[index].selectedRevisionId;
      }
      if (minOrder > truncateIndex) return slots[index].selectedRevisionId;
    }
    issues.add(
      LegacyGraphIssue(
        kind: 'truncate_out_of_range',
        severity: 'recovered',
        sourceEntityId: conversation.id,
        details: {'truncateIndex': truncateIndex},
      ),
    );
    return slots.last.selectedRevisionId;
  }

  static int _compareOrderedMessages(
    LegacyOrderedMessage a,
    LegacyOrderedMessage b,
  ) {
    final order = a.order.compareTo(b.order);
    if (order != 0) return order;
    final time = a.message.timestamp.compareTo(b.message.timestamp);
    if (time != 0) return time;
    return a.message.id.compareTo(b.message.id);
  }

  static int _compareGroups(
    List<LegacyOrderedMessage> a,
    List<LegacyOrderedMessage> b,
  ) => _compareOrderedMessages(
    a.reduce((x, y) => _compareOrderedMessages(x, y) <= 0 ? x : y),
    b.reduce((x, y) => _compareOrderedMessages(x, y) <= 0 ? x : y),
  );

  static String _stableId(String kind, String conversationId, String source) {
    final digest = sha256.convert(
      utf8.encode('$kind\u0000$conversationId\u0000$source'),
    );
    return 'legacy-${digest.toString().substring(0, 32)}';
  }
}

final class _Selection {
  const _Selection({required this.message, required this.ambiguous});

  final ChatMessage message;
  final bool ambiguous;
}
