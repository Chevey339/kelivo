import 'dart:convert';

import '../catalog/ui_budgets.dart';
import '../runtime/ui_surface_controller.dart' show UiGenerationStatus;

enum UiWebPhase { streaming, ready, interrupted, invalid }

enum UiWebError { metadata, sourceBudget, emptyDocument }

/// Metadata is plain text, and generated markup never becomes a parent DOM.
final class UiWebDocument {
  const UiWebDocument._({
    required this.source,
    required this.phase,
    this.title = '',
    this.summary = '',
    this.html = '',
    this.error,
  });

  final String source, title, summary, html;
  final UiWebPhase phase;
  final UiWebError? error;
  bool get canOpen => phase == UiWebPhase.ready;
  bool get hasMetadata => title.isNotEmpty;

  static UiWebDocument parse(
    String source, {
    required bool closed,
    required UiGenerationStatus generation,
  }) {
    UiWebDocument invalid(UiWebError error) => UiWebDocument._(
      source: source,
      phase: UiWebPhase.invalid,
      error: error,
    );
    if (source.length > UiBudgets.sourceBytes ||
        utf8.encode(source).length > UiBudgets.sourceBytes) {
      return invalid(UiWebError.sourceBudget);
    }
    final boundary = source.indexOf('\n');
    if (boundary < 0 &&
        !closed &&
        generation == UiGenerationStatus.generating) {
      return UiWebDocument._(source: source, phase: UiWebPhase.streaming);
    }
    final line = boundary < 0 ? source : source.substring(0, boundary);
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return invalid(UiWebError.metadata);
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 3 ||
        !decoded.keys.toSet().containsAll(const {
          'version',
          'title',
          'summary',
        }) ||
        decoded['version'] is! int ||
        decoded['version'] != 1 ||
        decoded['title'] is! String ||
        decoded['summary'] is! String) {
      return invalid(UiWebError.metadata);
    }
    final title = (decoded['title'] as String).trim();
    final summary = (decoded['summary'] as String).trim();
    if (title.isEmpty ||
        utf8.encode(title).length > 512 ||
        utf8.encode(summary).length > 2048) {
      return invalid(UiWebError.metadata);
    }
    final html = boundary < 0 ? '' : source.substring(boundary + 1);
    if (closed && html.trim().isEmpty) return invalid(UiWebError.emptyDocument);
    final phase = switch (generation) {
      UiGenerationStatus.generating => UiWebPhase.streaming,
      UiGenerationStatus.complete when closed => UiWebPhase.ready,
      _ => UiWebPhase.interrupted,
    };
    return UiWebDocument._(
      source: source,
      phase: phase,
      title: title,
      summary: summary,
      html: html,
    );
  }
}

/// Keep directives explicit: no generated content can precede the parent CSP,
/// and no interpolation enters a script, style or unquoted attribute.
abstract final class UiWebSandbox {
  static const frameId = 'kelivo-generated-document';
  static const closedTitle = 'Kelivo preview closed';
  static const emptyDocument =
      '<!doctype html><html><head><title>$closedTitle</title></head><body></body></html>';
  static const csp =
      "default-src 'none'; connect-src 'none'; worker-src 'none'; "
      "frame-src 'none'; object-src 'none'; form-action 'none'; base-uri 'none'; "
      "script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:;";
  static const _attribute = HtmlEscape(HtmlEscapeMode.attribute);

  static String wrap(String generatedHtml, {String title = 'Web preview'}) =>
      '''<!doctype html>
<html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="${_attribute.convert(csp)}">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:white}iframe{display:block;border:0;width:100%;height:100%}</style>
</head><body><iframe id="$frameId" title="${_attribute.convert(title)}" sandbox="allow-scripts" srcdoc="${_attribute.convert(generatedHtml)}"></iframe></body></html>''';

  /// Host-only teardown. Removing the child browsing context terminates its
  /// timers before the platform view and controller references are released.
  static const removeGeneratedDocument =
      'document.querySelectorAll("iframe").forEach(frame => frame.remove());';
}
