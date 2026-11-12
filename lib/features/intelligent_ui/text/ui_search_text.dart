import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import '../host/ui_presented_fences.dart';
import '../catalog/ui_budgets.dart';
import '../protocol/ui_source_hash.dart';
import '../protocol/ui_stream_parser.dart';
import '../runtime/ui_surface_controller.dart';
import '../runtime/ui_surface_state.dart';
import 'ui_text_projection.dart';

/// Cache wording is stable English so changing the app locale never rewrites
/// user data or changes the index's meaning. Model-authored labels/data keep
/// their original language. Visible controls use the normal ARB adapter.
final uiSearchProjection = UiTextProjection(
  UiProjectionLabels(
    defaultTitle: 'Interface',
    yes: 'Yes',
    no: 'No',
    empty: 'No visible data',
    omitted: 'Some fields or table rows are not included in search.',
    waiting: (id) => 'Waiting for $id',
    diagnostic: (d) => 'Interface cannot display this node (line ${d.line})',
    fieldIssue: (issue) => 'Field needs attention',
    chartKind: (kind, donut) => donut ? 'donut chart' : '${kind.name} chart',
    chartSummary: (kind, series, rows, missing) =>
        '$kind, $series series, $rows rows, $missing missing points',
    pieSummary: (kind, items, total) => '$kind, $items items, total $total',
    range: (name, min, max) => '$name: $min–$max',
    tablePage: (from, to, total) => 'Rows $from–$to of $total',
    filter: (query) => 'Filter: $query',
    domainGaps: (count) => '$count undefined points',
    trend: (value) => 'Change $value',
  ),
);

final class UiSearchSurfaceText {
  const UiSearchSurfaceText({required this.sourceHash, required this.text});
  final String sourceHash, text;
}

/// Initial values only: searching must not make every slider drag reindex data.
Map<String, UiSearchSurfaceText> initialUiSearchText(ChatMessage message) {
  final result = <String, UiSearchSurfaceText>{};
  for (final (:fence, :ordinal) in uiPresentedNativeFences(message)) {
    if (ordinal >= UiBudgets.blocksPerMessage) continue;
    if (!fence.node.closed) continue;
    final controller = UiSurfaceController(
      owner: UiSurfaceOwner(
        revisionId: message.id,
        surfaceKey: fence.surfaceKey,
      ),
      readOnly: true,
    );
    try {
      controller.updateSource(
        fence.body,
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      result[fence.surfaceKey] = UiSearchSurfaceText(
        sourceHash: uiSourceHash(controller.parsed.source),
        text: uiSearchProjection.text(
          controller.captureRead(),
          mode: UiTextMode.search,
        ),
      );
    } finally {
      controller.dispose();
    }
  }
  return result;
}

final class UiSearchText {
  const UiSearchText(this.text, this.surfaces);
  final String text;

  /// Ranges belong to [text], never to the original Markdown.
  final List<({int start, int end, String surfaceKey})> surfaces;
  String? surfaceAt(int offset) {
    for (final range in surfaces) {
      if (range.start <= offset && offset < range.end) return range.surfaceKey;
    }
    return null;
  }

  String? matchedSurface(Iterable<String> tokens) {
    for (final range in surfaces) {
      final value = text.substring(range.start, range.end).toLowerCase();
      if (tokens.any(value.contains)) return range.surfaceKey;
    }
    return null;
  }
}

UiSearchText uiSearchableText(
  ChatMessage message,
  Map<String, UiSearchSurfaceText> cached, {
  String Function(String)? ordinaryText,
}) {
  final out = StringBuffer();
  final ranges = <({int start, int end, String surfaceKey})>[];
  var cursor = 0;
  final source = message.content;
  for (final (:fence, :ordinal) in uiPresentedNativeFences(message)) {
    final start = fence.run.joinedStart + fence.node.span.start;
    final end = fence.run.joinedStart + fence.node.span.end;
    out.write(
      ordinaryText?.call(source.substring(cursor, start)) ??
          source.substring(cursor, start),
    );
    final from = out.length;
    final saved = cached[fence.surfaceKey];
    out.write(
      ordinal >= UiBudgets.blocksPerMessage
          ? 'Additional interface shown as source.'
          : saved != null &&
                !message.isStreaming &&
                message.generationState == GenerationRunState.completed &&
                saved.sourceHash ==
                    uiSourceHash(
                      UiStreamParser()
                          .update(fence.body, closed: fence.node.closed)
                          .source,
                    )
          ? saved.text
          : 'Interface is not complete.',
    );
    ranges.add((start: from, end: out.length, surfaceKey: fence.surfaceKey));
    cursor = end;
  }
  out.write(
    ordinaryText?.call(source.substring(cursor)) ?? source.substring(cursor),
  );
  return UiSearchText(out.toString(), ranges);
}
