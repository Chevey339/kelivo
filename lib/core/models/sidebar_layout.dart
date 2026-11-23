import 'dart:convert';

import 'package:flutter/foundation.dart';

enum SidebarEntry { search, history, translate, storage }

enum SidebarVisibility { show, more, hidden }

enum SidebarStyle { list, icons }

enum SidebarBlock {
  user('user'),
  search('search'),
  entries('entries'),
  assistant('assistant'),
  conversations('convs');

  const SidebarBlock(this.id);

  final String id;
}

enum SidebarPreset {
  current(SidebarLayout._(SidebarStyle.icons, _navigationOrder)),
  navigation(SidebarLayout._(SidebarStyle.list, _navigationOrder)),
  assistantAtBottom(
    SidebarLayout._(SidebarStyle.list, [
      SidebarBlock.search,
      SidebarBlock.entries,
      SidebarBlock.conversations,
      SidebarBlock.assistant,
      SidebarBlock.user,
    ]),
  ),
  allAtTop(
    SidebarLayout._(SidebarStyle.list, [
      SidebarBlock.user,
      SidebarBlock.assistant,
      SidebarBlock.search,
      SidebarBlock.entries,
      SidebarBlock.conversations,
    ]),
  );

  const SidebarPreset(this.layout);

  final SidebarLayout layout;
}

const _navigationOrder = [
  SidebarBlock.search,
  SidebarBlock.entries,
  SidebarBlock.assistant,
  SidebarBlock.conversations,
  SidebarBlock.user,
];

@immutable
class SidebarLayout {
  const SidebarLayout._(this.style, this.order);

  factory SidebarLayout.fromPreferences(String? style, List<String>? order) {
    final blocks = {
      for (final id in order ?? const <String>[])
        for (final block in SidebarBlock.values)
          if (block.id == id) block,
    };
    return SidebarLayout._(
      style == SidebarStyle.list.name ? SidebarStyle.list : SidebarStyle.icons,
      blocks.length == SidebarBlock.values.length
          ? List.unmodifiable(blocks)
          : _navigationOrder,
    );
  }

  final SidebarStyle style;
  final List<SidebarBlock> order;

  Iterable<SidebarBlock> get visibleOrder => order.where(
    (block) => style == SidebarStyle.list || block != SidebarBlock.entries,
  );

  SidebarPreset? get preset {
    final visible = visibleOrder.toList();
    for (final preset in SidebarPreset.values) {
      if (preset.layout.style == style &&
          listEquals(preset.layout.visibleOrder.toList(), visible)) {
        return preset;
      }
    }
    return null;
  }

  bool isBelowConversations(SidebarBlock block) =>
      order.indexOf(block) > order.indexOf(SidebarBlock.conversations);

  SidebarLayout withStyle(SidebarStyle style) => SidebarLayout._(style, order);

  SidebarLayout moveBlock(SidebarBlock block, int target) {
    final visible = visibleOrder.toList();
    if (block == SidebarBlock.conversations || !visible.remove(block)) {
      return this;
    }
    visible.insert(target.clamp(0, visible.length), block);
    if (style == SidebarStyle.icons) {
      visible.insert(order.indexOf(SidebarBlock.entries), SidebarBlock.entries);
    }
    return SidebarLayout._(style, List.unmodifiable(visible));
  }
}

const defaultMobileSidebarEntries = {
  SidebarEntry.history: SidebarVisibility.show,
  SidebarEntry.translate: SidebarVisibility.show,
};

const defaultDesktopSidebarEntries = {
  SidebarEntry.search: SidebarVisibility.show,
  SidebarEntry.translate: SidebarVisibility.show,
  SidebarEntry.storage: SidebarVisibility.show,
  SidebarEntry.history: SidebarVisibility.show,
};

Map<SidebarEntry, SidebarVisibility> decodeSidebarEntries(
  String? json,
  Map<SidebarEntry, SidebarVisibility> defaults,
) {
  if (json == null) return defaults;
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return defaults;
  }
  if (decoded is! List) return defaults;
  final entries = <SidebarEntry, SidebarVisibility>{};
  for (final row in decoded.whereType<Map>()) {
    for (final entry in defaults.keys) {
      if (entry.name != row['id']) continue;
      final visibility = SidebarVisibility.values.asNameMap()[row['vis']];
      if (visibility != null) entries.putIfAbsent(entry, () => visibility);
    }
  }
  for (final entry in defaults.entries) {
    entries.putIfAbsent(entry.key, () => entry.value);
  }
  return Map.unmodifiable(entries);
}

String encodeSidebarEntries(Map<SidebarEntry, SidebarVisibility> entries) =>
    jsonEncode([
      for (final entry in entries.entries)
        {'id': entry.key.name, 'vis': entry.value.name},
    ]);

List<SidebarEntry> sidebarEntriesWithVisibility(
  Map<SidebarEntry, SidebarVisibility> entries,
  SidebarVisibility visibility,
) => [
  for (final entry in entries.entries)
    if (entry.value == visibility) entry.key,
];
