import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../providers/settings_provider.dart';
import '../services/api/carried_truncation.dart';
import '../services/api/request_token_estimate.dart';
import '../../features/chat/utils/thinking_tag_parser.dart';
import 'carried_original.dart';
import 'chat_message.dart';
import 'compress_context_options.dart';
import 'context_operation.dart';
import 'image_context.dart';
import 'message_part.dart';
import 'native_compaction.dart';

class CarryRow {
  const CarryRow({
    required this.item,
    required this.selected,
    required this.tokens,
    this.availableReply,
    this.replyInRetained = false,
    this.hadAttachments = false,
    this.attachmentCount = 0,
    this.replyDoesNotFit = false,
  });
  final CarriedOriginal item;
  final bool selected;
  final int tokens;
  final CarriedReply? availableReply;
  final bool replyInRetained;
  final bool hadAttachments;
  final int attachmentCount;
  final bool replyDoesNotFit;
}

class CarrySelection {
  const CarrySelection({
    this.rows = const [],
    this.items = const [],
    this.totalTokens = 0,
    this.notFit = 0,
    this.overBudget = false,
    this.reachedBudget = false,
    this.fitCount = 0,
  });
  final List<CarryRow> rows;
  final List<CarriedOriginal> items;
  final int totalTokens;
  final int notFit;
  final bool overBudget;
  final bool reachedBudget;
  final int fitCount;
  CarriedOriginals freeze(
    CarrySetting setting, {
    bool fromSummaries = false,
    String origin = 'explicit',
  }) => CarriedOriginals(
    setting: setting,
    fromSummaries: fromSummaries,
    origin: origin,
    notFit: notFit,
    items: items,
  );
}

int countCarriedTokens(CarriedOriginal item, ProviderKind kind) =>
    estimateRequestInput({
      'input': [item.wireItem],
    }, kind) +
    (item.reply == null
        ? 0
        : estimateRequestInput({
            'input': [textWire('assistant', item.reply!.effectiveText)],
          }, kind));

CarriedOriginal carriedFromMessage(
  ChatMessage m, {
  bool includeAttachments = true,
  bool fingerprint = true,
}) => CarriedOriginal(
  sourceMessageId: m.id,
  sourceGroupId: ContextHistory.group(m),
  sourceVersion: m.version,
  contentHash: !fingerprint
      ? ''
      : sha256
            .convert(
              utf8.encode(
                jsonEncode(
                  m.parts.map((p) => [p.kind, p.encodePayload()]).toList(),
                ),
              ),
            )
            .toString(),
  text: m.content,
  attachmentCount: includeAttachments
      ? m.parts.where((p) => p is ImagePart || p is FilePart).length
      : 0,
  imageHandles: includeAttachments
      ? [
          for (var i = 0; i < m.parts.length; i++)
            if (m.parts[i] is ImagePart)
              ContextImageIdentity(m.id, 'part:$i').handle,
        ]
      : [],
  hasAttachments: includeAttachments && m.parts.any((p) => p is! TextPart),
);

Map<String, List<CarriedOriginal>> inheritedCarryItems(
  List<ChatMessage> messages,
  List<ContextOperation> operations,
  List<String> dependencies, {
  Map<String, String> frozenPrompts = const {},
  Set<String>? availableRevisionIds,
}) {
  final result = <String, List<CarriedOriginal>>{};
  final relevant = dependencies.toSet();
  final byId = {for (final m in messages) m.id: m};
  for (final op in operations.where((op) => relevant.contains(op.id))) {
    final carried = op.carried;
    if (carried != null) {
      result[op.id] = [
        for (final item in carried.items)
          item.copyWith(
            text: item.effectiveText,
            clearEdit: true,
            inheritedEdit: item.isEdited,
            wire: item.wire == null ? null : item.wireItem,
            fromOperationId: op.id,
          ),
      ];
      continue;
    }
    final payload = op.nativePayload;
    if (payload?.protocol != NativeCompactionProtocol.codex) continue;
    final sources = op.legacyUserSources(
      messages,
      frozenPrompts: frozenPrompts,
      availableRevisionIds: availableRevisionIds,
    );
    result[op.id] = [
      for (final (index, wire) in payload!.output.indexed)
        if (sources[index] case final id?)
          (byId[id] == null
                  ? CarriedOriginal(
                      sourceMessageId: id,
                      sourceGroupId: id,
                      sourceVersion: 0,
                      contentHash: sha256
                          .convert(utf8.encode(jsonEncode(wire)))
                          .toString(),
                      text: '',
                    )
                  : carriedFromMessage(byId[id]!))
              .copyWith(
                text: carriedWireText(wire),
                wire: wire,
                fromOperationId: op.id,
                truncated: carriedWireText(wire).contains('[…truncated…]'),
              ),
    ];
  }
  return result;
}

/// Insert missing originals in the order frozen by their operation. A copied
/// chat has a summary row to anchor them but no local user revisions.
List<String> orderedCarryIds({
  required List<ContextMessageMetadata> messages,
  required List<ContextOperation> operations,
  required List<String> dependencies,
  required Iterable<String> direct,
  required Iterable<ContextMessageMetadata> covered,
  required Set<String> retained,
  required bool fromSummaries,
  required Map<String, List<CarriedOriginal>> inherited,
}) {
  final positions = {for (final (i, m) in messages.indexed) m.id: i};
  final groupPositions = {for (final (i, m) in messages.indexed) m.groupId: i};
  final byId = {for (final op in operations) op.id: op};
  final copiedRows = {
    for (final op in operations)
      if (positions.containsKey(op.id) && op.isCompression) op.id,
  };
  final ids = {...direct};
  if (fromSummaries) {
    final groups = <String>{};
    final visited = <String>{};
    void addGroups(String id) {
      if (!visited.add(id)) return;
      final op = byId[id];
      if (op == null) return;
      groups.addAll(op.sourceGroups);
      op.dependencies.forEach(addGroups);
    }

    dependencies.forEach(addGroups);
    ids.addAll(
      covered
          .where((m) => m.isUserMessage && groups.contains(m.groupId))
          .map((m) => m.id),
    );
  }
  final before = <int, List<String>>{};
  for (final entry in inherited.entries) {
    final op = byId[entry.key]!;
    var next = (groupPositions[op.anchorGroupId] ?? -1) + 1;
    final sourceOrder = <String, int>{};
    for (final group in op.sourceGroups.reversed) {
      next = groupPositions[group] ?? next;
      sourceOrder[group] = next;
    }
    next = (groupPositions[op.anchorGroupId] ?? -1) + 1;
    final missing = <(int, String)>[];
    for (final item in entry.value.reversed) {
      final id = item.sourceMessageId;
      ids.add(id);
      if (positions[id] case final position?) {
        next = position;
      } else {
        next = (sourceOrder[item.sourceGroupId] ?? next).clamp(0, next);
        missing.add((next, id));
      }
    }
    for (final (position, id) in missing.reversed) {
      (before[position] ??= []).add(id);
    }
  }
  ids.removeAll(retained);
  ids.removeAll(copiedRows);
  final chronological = <String>[];
  for (var i = 0; i <= messages.length; i++) {
    for (final id in before[i] ?? const <String>[]) {
      if (ids.remove(id)) chronological.add(id);
    }
    if (i < messages.length && ids.remove(messages[i].id)) {
      chronological.add(messages[i].id);
    }
  }
  return chronological.reversed.toList();
}

/// One deterministic selection for the preview and execution. Exclusions occupy
/// their count slot; all-mode stops at the first item that cannot fit.
CarrySelection selectCarriedOriginals({
  required List<ChatMessage> messages,
  required List<ContextOperation> operations,
  required CompressionSelection selection,
  required CarrySetting setting,
  required bool fromSummaries,
  required Set<String> excluded,
  required Set<String> replies,
  required int? budgetTokens,
  required int Function(CarriedOriginal) count,
  ProviderKind kind = ProviderKind.openai,
  bool includeAttachments = true,
  bool newConversation = false,
  Map<String, Map<String, dynamic>> wires = const {},
  Map<String, String> attachmentTexts = const {},
  Map<String, String> plainTexts = const {},
  List<String>? orderedIds,
  Map<String, List<CarriedOriginal>>? inheritedItems,
  bool nativeWire = false,
  bool automaticWire = false,
  Map<String, List<String>> images = const {},
}) {
  if (setting.mode == CarryMode.off || setting.mode == CarryMode.unset) {
    return const CarrySelection();
  }
  final retained = selection.retained.map((m) => m.id).toSet();
  final positions = {
    for (var i = 0; i < messages.length; i++) messages[i].id: i,
  };
  final inherited =
      inheritedItems ??
      inheritedCarryItems(messages, operations, selection.dependencies);
  final order =
      orderedIds ??
      orderedCarryIds(
        messages: messages.map(ContextMessageMetadata.fromMessage).toList(),
        operations: operations,
        dependencies: selection.dependencies,
        direct: selection.effective
            .where(isCompressionUserMessage)
            .map((m) => m.id),
        covered: selection.covered.map(ContextMessageMetadata.fromMessage),
        retained: retained,
        fromSummaries: fromSummaries,
        inherited: inherited,
      );
  final copies = {
    for (final items in inherited.values)
      for (final item in items) item.sourceMessageId: item,
  };
  final ordered = [
    for (final id in order)
      if (copies[id] case final item?)
        item
      else if (positions[id] case final index?)
        carriedFromMessage(
          messages[index],
          includeAttachments: includeAttachments,
          fingerprint: false,
        ),
  ];
  final rows = <CarryRow>[];
  final items = <CarriedOriginal>[];
  var total = 0;
  var notFit = 0;
  var fitCount = 0;
  var fitting = true;
  var reachedBudget = false;
  final limit = setting.mode == CarryMode.count
      ? setting.count
      : ordered.length;
  final budget = budgetTokens ?? (setting.mode == CarryMode.all ? 64000 : null);
  for (var i = 0; i < ordered.length && i < limit; i++) {
    var item = ordered[i];
    if (item.fromOperationId == null &&
        images[item.sourceMessageId]?.isNotEmpty == true) {
      item = item.copyWith(
        imageHandles: images[item.sourceMessageId],
        hasAttachments: true,
      );
    }
    final hadAttachments = item.hasAttachments;
    final attachmentCount = item.attachmentCount > 0
        ? item.attachmentCount
        : item.imageHandles.length;
    if (!includeAttachments && item.fromOperationId != null) {
      item = item
          .copyWith(
            text: item.isEdited
                ? item.effectiveText
                : item.textWithoutAttachments,
          )
          .textOnly();
    }
    if (attachmentTexts[item.sourceMessageId] case final String extracted
        when item.fromOperationId == null) {
      item = item.copyWith(
        text: extracted,
        textWithoutAttachments: item.hasAttachments
            ? plainTexts[item.sourceMessageId]
            : null,
      );
    }
    final oldReply = item.reply;
    final wire = wires[item.sourceMessageId] ?? item.wire;
    item = item.copyWith(removeReply: true, clearWire: !nativeWire);
    if (nativeWire && wire != null) {
      final text = automaticWire ? carriedWireText(wire) : item.effectiveText;
      item = item.copyWith(
        text: text,
        clearEdit: true,
        wire: automaticWire ? wire : explicitCarriedWire(wire, text),
      );
    }
    if ((newConversation && !automaticWire) ||
        (!positions.containsKey(item.sourceMessageId) &&
            !item.sourceMessageId.startsWith('legacy-native:'))) {
      item = item.textOnly();
    }
    final replyMessages = <ChatMessage>[];
    final pos = positions[item.sourceMessageId];
    if (pos != null) {
      for (final m in messages.skip(pos + 1)) {
        if (isCompressionUserMessage(m)) break;
        if (m.role == 'assistant') replyMessages.add(m);
      }
    }
    final replyText = replyMessages
        .map((m) => ThinkingTagParser.parseWithRanges(m.content).visibleContent)
        .where((t) => t.trim().isNotEmpty)
        .join('\n\n');
    final available = oldReply != null
        ? CarriedReply(
            messageIds: oldReply.messageIds,
            text: oldReply.text,
            editedText: oldReply.editedText,
            estimatedTokens: estimateRequestInput({
              'input': [textWire('assistant', oldReply.effectiveText)],
            }, kind),
          )
        : replyText.trim().isEmpty
        ? null
        : CarriedReply(
            messageIds: replyMessages.map((m) => m.id).toList(),
            text: replyText,
            estimatedTokens: estimateRequestInput({
              'input': [textWire('assistant', replyText)],
            }, kind),
          );
    final inRetained = available?.messageIds.any(retained.contains) ?? false;
    final selected = !excluded.contains(item.sourceMessageId);
    if (selected &&
        replies.contains(item.sourceMessageId) &&
        !inRetained &&
        available != null) {
      item = item.copyWith(reply: available);
    }
    var tokens = count(item);
    if (selected &&
        setting.mode == CarryMode.all &&
        budget != null &&
        total + tokens > budget) {
      reachedBudget = true;
      final shortened = item.reply == null && !item.hasAttachments
          ? truncateCarriedText(item.wireItem, budget - total, kind: kind)
          : null;
      if (shortened != null) {
        item = item.copyWith(
          text: carriedWireText(shortened),
          clearEdit: true,
          truncated: true,
          wire: item.wire == null ? null : shortened,
        );
        tokens = count(item);
        if (total + tokens <= budget) {
          items.add(item.copyWith(estimatedTokens: tokens));
          total += tokens;
          rows.add(
            CarryRow(
              item: item,
              selected: true,
              tokens: tokens,
              availableReply: available,
              replyInRetained: inRetained,
              hadAttachments: hadAttachments,
              attachmentCount: attachmentCount,
            ),
          );
        } else {
          notFit++;
        }
      } else {
        notFit++;
        if (item.reply != null) {
          rows.add(
            CarryRow(
              item: item,
              selected: true,
              tokens: count(item.copyWith(removeReply: true)),
              availableReply: available,
              replyDoesNotFit: true,
              hadAttachments: hadAttachments,
              attachmentCount: attachmentCount,
            ),
          );
        }
      }
      notFit += ordered
          .skip(i + 1)
          .where((m) => !excluded.contains(m.sourceMessageId))
          .length;
      break;
    }
    if (selected) {
      if (budget != null && total + tokens > budget) fitting = false;
      total += tokens;
      items.add(item.copyWith(estimatedTokens: tokens));
    }
    if (fitting) fitCount = i + 1;
    rows.add(
      CarryRow(
        item: item,
        selected: selected,
        tokens: item.reply == null
            ? tokens
            : count(item.copyWith(removeReply: true)),
        availableReply: available,
        replyInRetained: inRetained,
        hadAttachments: hadAttachments,
        attachmentCount: attachmentCount,
      ),
    );
  }
  final frozen = <CarriedOriginal>[];
  for (var item in items.reversed) {
    if (newConversation && automaticWire) {
      item = item.textOnly();
      item = item.copyWith(estimatedTokens: count(item));
    }
    final pos = positions[item.sourceMessageId];
    if (item.contentHash.isEmpty && pos != null) {
      item = item.copyWith(
        contentHash: carriedFromMessage(messages[pos]).contentHash,
      );
    }
    frozen.add(item);
  }
  return CarrySelection(
    rows: rows,
    items: frozen,
    totalTokens: frozen.fold(0, (sum, item) => sum + item.estimatedTokens),
    notFit: notFit,
    overBudget:
        setting.mode == CarryMode.count &&
        items.isNotEmpty &&
        budget != null &&
        total > budget,
    fitCount: fitCount,
    reachedBudget: reachedBudget,
  );
}

/// Isolate input contains data only, never UI state, HTTP clients or callbacks.
class CarriedSelectionJob {
  const CarriedSelectionJob({
    required this.messages,
    required this.operations,
    required this.selection,
    required this.options,
    required this.setting,
    required this.budgetTokens,
    required this.kind,
    this.wires = const {},
    this.attachmentTexts = const {},
    this.orderedIds,
    this.inheritedItems,
    this.automaticWire = false,
    this.plainTexts = const {},
    this.images = const {},
    this.automatic = false,
  });
  final List<ChatMessage> messages;
  final List<ContextOperation> operations;
  final CompressionSelection selection;
  final CompressContextOptions options;
  final CarrySetting setting;
  final int? budgetTokens;
  final ProviderKind kind;
  final Map<String, Map<String, dynamic>> wires;
  final Map<String, String> attachmentTexts;
  final List<String>? orderedIds;
  final Map<String, List<CarriedOriginal>>? inheritedItems;
  final bool automaticWire;
  final Map<String, String> plainTexts;
  final Map<String, List<String>> images;
  final bool automatic;
  CarrySelection call() => selectCarriedOriginals(
    messages: messages,
    operations: operations,
    selection: selection,
    setting: setting,
    fromSummaries: !automatic && options.carryFromSummaries,
    excluded: options.carryExcluded.toSet(),
    replies: automatic ? {} : options.carryReplies.toSet(),
    budgetTokens: budgetTokens,
    kind: kind,
    includeAttachments: options.includeAttachmentsAndTools,
    newConversation: options.newConversation,
    wires: wires,
    attachmentTexts: attachmentTexts,
    orderedIds: orderedIds,
    inheritedItems: inheritedItems,
    nativeWire: options.native,
    automaticWire: automaticWire,
    plainTexts: plainTexts,
    images: images,
    count: (item) => countCarriedTokens(item, kind),
  );
}
