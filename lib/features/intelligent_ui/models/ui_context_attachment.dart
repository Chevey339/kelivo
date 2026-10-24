import 'package:Kelivo/utils/unicode_sanitizer.dart';
import 'dart:convert';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';

/// Frozen, human-readable message text. The framing identifies a separate
/// ordinary TextPart for the read-only user chip; it grants no UI authority.
final class UiContextText {
  UiContextText._(this.title, this.body, this.exactText);
  static const prefix = '[Kelivo UI state] ';
  static const suffix = '\n[/Kelivo UI state]';
  final String title, body, exactText;

  factory UiContextText({required String title, required String body}) {
    title = UnicodeSanitizer.sanitize(title);
    body = UnicodeSanitizer.sanitize(body);
    if (title.isEmpty || utf8.encode(title).length > 256 || body.isEmpty) {
      throw const FormatException('Invalid UI context text');
    }
    final text = '$prefix${jsonEncode(title)}\n$body$suffix';
    if (utf8.encode(text).length > UiBudgets.modelContentBytes) {
      throw const FormatException('UI context exceeds its byte budget');
    }
    return UiContextText._(title, body, text);
  }

  static int bodyBudget(String title) =>
      UiBudgets.modelContentBytes -
      utf8.encode('$prefix${jsonEncode(title)}\n$suffix').length;

  /// The caller only recognizes this framing in a complete leading TextPart,
  /// never by rescanning arbitrary Markdown or assistant/tool output.
  static UiContextText? parseSentPart(String source) {
    if (!source.startsWith(prefix) ||
        !source.endsWith(suffix) ||
        source.length > UiBudgets.modelContentBytes ||
        utf8.encode(source).length > UiBudgets.modelContentBytes) {
      return null;
    }
    final line = source.indexOf('\n');
    final bodyEnd = source.length - suffix.length;
    if (line < prefix.length || line + 1 >= bodyEnd) return null;
    try {
      final title = jsonDecode(source.substring(prefix.length, line));
      if (title is! String) return null;
      final result = UiContextText(
        title: title,
        body: source.substring(line + 1, bodyEnd),
      );
      return result.exactText == source ? result : null;
    } on FormatException {
      return null;
    }
  }

  String get summary => String.fromCharCodes(
    body
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(3)
        .join(' · ')
        .runes
        .take(160),
  );

  @override
  bool operator ==(Object other) =>
      other is UiContextText && other.exactText == exactText;
  @override
  int get hashCode => exactText.hashCode;
}

/// Provenance for a newly attached, not-yet-sent snapshot. The host also checks
/// the conversation's selected revision at the final coordinated write.
final class UiContextSource {
  UiContextSource({
    required this.conversationId,
    required this.revisionId,
    required this.surfaceKey,
    required this.sourceHash,
  }) {
    for (final id in [conversationId, revisionId]) {
      if (id.isEmpty || utf8.encode(id).length > 256) {
        throw const FormatException('Invalid UI context owner');
      }
    }
    if (!RegExp(r'^[0-9]+:[0-9]+$').hasMatch(surfaceKey) ||
        surfaceKey.length > 48 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sourceHash)) {
      throw const FormatException('Invalid UI context source identity');
    }
  }
  final String conversationId, revisionId, surfaceKey, sourceHash;
  Map<String, Object?> toJson() => {
    'conversationId': conversationId,
    'revisionId': revisionId,
    'surfaceKey': surfaceKey,
    'sourceHash': sourceHash,
  };
  factory UiContextSource.fromJson(Map<String, dynamic> json) {
    const names = {'conversationId', 'revisionId', 'surfaceKey', 'sourceHash'};
    if (json.length != names.length ||
        !json.keys.every(names.contains) ||
        json.values.any((value) => value is! String)) {
      throw const FormatException('Invalid UI context source');
    }
    return UiContextSource(
      conversationId: json['conversationId'] as String,
      revisionId: json['revisionId'] as String,
      surfaceKey: json['surfaceKey'] as String,
      sourceHash: json['sourceHash'] as String,
    );
  }
  @override
  bool operator ==(Object other) =>
      other is UiContextSource &&
      other.conversationId == conversationId &&
      other.revisionId == revisionId &&
      other.surfaceKey == surfaceKey &&
      other.sourceHash == sourceHash;
  @override
  int get hashCode =>
      Object.hash(conversationId, revisionId, surfaceKey, sourceHash);
}

/// Frozen context in a composer. New attachments retain their provenance for
/// stale-source checks. Editing an already-sent user message preserves its
/// historical text without inventing a live source or revisiting past values.
final class UiContextAttachment {
  const UiContextAttachment.attached({
    required UiContextSource this.source,
    required this.text,
  });
  const UiContextAttachment.history(this.text) : source = null;
  final UiContextSource? source;
  final UiContextText text;
  bool get previouslySent => source == null;

  Map<String, Object?> toJson() => {
    'version': 1,
    'source': source?.toJson(),
    'title': text.title,
    'body': text.body,
  };
  factory UiContextAttachment.fromJson(Map<String, dynamic> json) {
    const names = {'version', 'source', 'title', 'body'};
    if (json.length != names.length ||
        !json.keys.every(names.contains) ||
        json['version'] is! int ||
        json['version'] != 1 ||
        json['title'] is! String ||
        json['body'] is! String ||
        (json['source'] != null && json['source'] is! Map<String, dynamic>)) {
      throw const FormatException('Invalid saved UI context');
    }
    final text = UiContextText(
      title: json['title'] as String,
      body: json['body'] as String,
    );
    final source = json['source'];
    return source == null
        ? UiContextAttachment.history(text)
        : UiContextAttachment.attached(
            source: UiContextSource.fromJson(source as Map<String, dynamic>),
            text: text,
          );
  }
  @override
  bool operator ==(Object other) =>
      other is UiContextAttachment &&
      other.source == source &&
      other.text == text;
  @override
  int get hashCode => Object.hash(source, text);
}
