import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/memory_entry.dart';
import '../../models/user_profile_field.dart';
import 'memory_prompts.dart';

/// Pure serialization for memory / profile injection blocks (§7.2–§7.5, §13.5).
///
/// No database, no `DateTime.now()`, no locale lookups.
abstract final class MemoryBlockBuilder {
  MemoryBlockBuilder._();

  static const List<MemoryType> _typeOrder = [
    MemoryType.identity,
    MemoryType.workflow,
    MemoryType.voice,
    MemoryType.instruction,
  ];

  static String buildMemoryBlock({
    required List<MemoryEntry> visible,
    required Map<MemoryType, int> totalByType,
    required MemoryPromptLang lang,
    required int maxItems,
  }) {
    final out = StringBuffer();
    for (final type in _typeOrder) {
      final list = visible.where((e) => e.type == type).toList();
      if (list.isEmpty) {
        out.writeln('<user_memory type="${MemoryEntry.typeToString(type)}"/>');
        continue;
      }

      final total = totalByType[type] ?? list.length;
      final summary = total > maxItems;
      List<MemoryEntry> selected;
      if (!summary) {
        selected = List<MemoryEntry>.from(list);
      } else {
        selected = List<MemoryEntry>.from(list)
          ..sort((a, b) {
            final byUpdated = b.updatedAt.compareTo(a.updatedAt);
            if (byUpdated != 0) return byUpdated;
            return a.id.compareTo(b.id);
          });
        if (selected.length > maxItems) {
          selected = selected.sublist(0, maxItems);
        }
      }

      selected.sort((a, b) {
        final byScope = _scopeRank(a.scope).compareTo(_scopeRank(b.scope));
        if (byScope != 0) return byScope;
        final byCreated = a.createdAt.compareTo(b.createdAt);
        if (byCreated != 0) return byCreated;
        return a.id.compareTo(b.id);
      });

      if (summary) {
        out.writeln(
          '<user_memory type="${MemoryEntry.typeToString(type)}" mode="summary" total="$total" shown="${selected.length}">',
        );
      } else {
        out.writeln('<user_memory type="${MemoryEntry.typeToString(type)}">');
      }

      for (final e in selected) {
        final marker = e.scope == MemoryScope.assistant ? '(assistant) ' : '';
        out.writeln(
          '- [${fmtDate(e.updatedAt)}] $marker${flatten(escape(e.content))}',
        );
      }

      if (summary) {
        out.writeln(MemoryPrompts.moreHintFor(lang));
      }
      out.writeln('</user_memory>');
    }
    return out.toString();
  }

  static String buildProfileBlock({
    required List<UserProfileField> fields,
    required MemoryPromptLang lang,
  }) {
    // Profile tags are language-neutral (§7.3); [lang] kept for §13.5 API.
    final nonEmpty = fields
        .where((f) => f.value.trim().isNotEmpty)
        .toList(growable: false);
    if (nonEmpty.isEmpty) return '<user_profile/>\n';

    final byKey = {for (final f in nonEmpty) f.key: f};
    final out = StringBuffer('<user_profile>\n');
    for (final k in UserProfileField.knownKeys) {
      final field = byKey[k];
      if (field == null) continue;
      out.writeln('<$k>${escape(field.value)}</$k>');
    }
    final customKeys = byKey.keys.where((k) => k.startsWith('custom.')).toList()
      ..sort();
    for (final k in customKeys) {
      final name = k.substring('custom.'.length);
      final field = byKey[k]!;
      out.writeln(
        '<custom name="${escapeAttr(name)}">${escape(field.value)}</custom>',
      );
    }
    out.writeln('</user_profile>');
    return out.toString();
  }

  /// SHA-256 of `profileBlock + memoryBlock`, hex, first 16 chars (§7.4).
  static String hashBlocks(String profileBlock, String memoryBlock) {
    final digest = sha256.convert(utf8.encode(profileBlock + memoryBlock));
    return digest.toString().substring(0, 16);
  }

  static String buildFullSnapshotPrefix(
    String profileBlock,
    String memoryBlock,
    MemoryPromptLang lang,
  ) {
    return '${MemoryPrompts.introFullFor(lang)}\n'
        '$profileBlock$memoryBlock\n';
  }

  /// Exclusive end index of a §7.6 prefix at the start of [payload], or null.
  ///
  /// Injection only ever writes full snapshots, but conversations frozen by
  /// earlier versions carry `<user_memory_update>` blocks that still have to be
  /// recognized so they can be stripped once superseded.
  static int? endOfInjectedPrefix(String payload) {
    if (payload.isEmpty) return null;
    return _endOfUpdatePrefix(payload) ?? _endOfFullPrefix(payload);
  }

  /// Split a frozen user payload into snapshot prefix + remaining user text.
  static ({String prefix, String rest, String kind})? splitInjectedPrefix(
    String payload,
  ) {
    final updateEnd = _endOfUpdatePrefix(payload);
    if (updateEnd != null) {
      return (
        prefix: payload.substring(0, updateEnd),
        rest: payload.substring(updateEnd),
        kind: 'update',
      );
    }
    final fullEnd = _endOfFullPrefix(payload);
    if (fullEnd != null) {
      return (
        prefix: payload.substring(0, fullEnd),
        rest: payload.substring(fullEnd),
        kind: 'full',
      );
    }
    return null;
  }

  static int? _endOfUpdatePrefix(String payload) {
    final intro = _leadingIntro(payload, update: true);
    if (intro == null) return null;
    const close = '</user_memory_update>';
    final closeAt = payload.indexOf(close, intro.length);
    if (closeAt < 0) return null;
    var end = closeAt + close.length;
    if (payload.startsWith('\n\n', end)) return end + 2;
    if (payload.startsWith('\n', end)) return end + 1;
    return end;
  }

  static int? _endOfFullPrefix(String payload) {
    final intro = _leadingIntro(payload, update: false);
    if (intro == null) return null;
    var cursor = intro.length;
    if (payload.startsWith('\n', cursor)) cursor++;

    final profile = _consumeProfileBlock(payload, cursor);
    if (profile == null) return null;
    cursor = profile;

    for (final type in _typeOrder) {
      final next = _consumeMemoryBlock(payload, cursor, type);
      if (next == null) return null;
      cursor = next;
    }
    if (payload.startsWith('\n', cursor)) cursor++;
    return cursor;
  }

  static String? _leadingIntro(String payload, {required bool update}) {
    final candidates = update
        ? [MemoryPrompts.introUpdateZh, MemoryPrompts.introUpdateEn]
        : [MemoryPrompts.introFullZh, MemoryPrompts.introFullEn];
    for (final intro in candidates) {
      if (payload.startsWith(intro)) return intro;
    }
    return null;
  }

  static int? _consumeProfileBlock(String payload, int start) {
    const empty = '<user_profile/>';
    if (payload.startsWith(empty, start)) {
      var end = start + empty.length;
      if (payload.startsWith('\n', end)) end++;
      return end;
    }
    const open = '<user_profile>';
    const close = '</user_profile>';
    if (!payload.startsWith(open, start)) return null;
    final closeAt = payload.indexOf(close, start + open.length);
    if (closeAt < 0) return null;
    var end = closeAt + close.length;
    if (payload.startsWith('\n', end)) end++;
    return end;
  }

  static int? _consumeMemoryBlock(String payload, int start, MemoryType type) {
    final head = '<user_memory type="${MemoryEntry.typeToString(type)}"';
    if (!payload.startsWith(head, start)) return null;
    final gt = payload.indexOf('>', start);
    if (gt < 0) return null;
    final tag = payload.substring(start, gt + 1);
    if (tag.endsWith('/>')) {
      var end = gt + 1;
      if (payload.startsWith('\n', end)) end++;
      return end;
    }
    const close = '</user_memory>';
    final closeAt = payload.indexOf(close, gt + 1);
    if (closeAt < 0) return null;
    var end = closeAt + close.length;
    if (payload.startsWith('\n', end)) end++;
    return end;
  }

  static int _scopeRank(MemoryScope scope) {
    switch (scope) {
      case MemoryScope.global:
        return 0;
      case MemoryScope.assistant:
        return 1;
    }
  }

  /// `yyyy-MM-dd` from the local timezone of [timestamp].
  static String fmtDate(DateTime timestamp) {
    final local = timestamp.isUtc ? timestamp.toLocal() : timestamp;
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Escape `&`, `<`, `>` only (entry content never enters attributes).
  static String escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// Escape for XML attribute values (`"` in addition to [escape]).
  static String escapeAttr(String text) {
    return escape(text).replaceAll('"', '&quot;');
  }

  /// Collapse newlines and whitespace runs to a single space, then trim.
  static String flatten(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
