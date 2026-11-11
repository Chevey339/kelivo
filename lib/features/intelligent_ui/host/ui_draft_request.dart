import '../protocol/ui_ir.dart';
import '../protocol/ui_diagnostic.dart';
import '../protocol/ui_expression_walk.dart';
import '../models/ui_context_attachment.dart';
import '../runtime/ui_surface_controller.dart';
import '../runtime/ui_surface_state.dart';
import '../text/ui_bounded_text.dart';

/// Captured before opening any composer dialog. This is a draft, never a send.
final class UiDraftRequest {
  const UiDraftRequest({
    required this.conversationId,
    this.attachment,
    this.text = '',
  });
  final String conversationId, text;
  final UiContextAttachment? attachment;

  factory UiDraftRequest.attach({
    required String conversationId,
    required UiSurfaceSnapshot snapshot,
    required UiContextText context,
    String text = '',
  }) => UiDraftRequest(
    conversationId: conversationId,
    text: text,
    attachment: UiContextAttachment.attached(
      source: UiContextSource(
        conversationId: conversationId,
        revisionId: snapshot.owner.revisionId,
        surfaceKey: snapshot.owner.surfaceKey,
        sourceHash: snapshot.sourceHash,
      ),
      text: context,
    ),
  );

  factory UiDraftRequest.repair({
    required String conversationId,
    required UiSurfaceController controller,
    required String introduction,
    required String omitted,
  }) {
    final read = controller.captureRead();
    final out = UiBoundedText(4096, omission: omitted);
    out.add(introduction);
    final lines = controller.parsed.source.split('\n');
    final included = <int>{};
    final diagnostics = <(UiDiagnosticCode, int, String?)>{};
    void excerpt(int at) {
      for (var line = at - 1; line <= at + 1; line++) {
        if (line < 1 || line > lines.length || !included.add(line)) continue;
        out.add('$line: ${lines[line - 1]}');
      }
    }

    void diagnostic(UiDiagnosticCode code, int line, String? symbol) {
      if (!diagnostics.add((code, line, symbol))) return;
      out.add('${code.name} · $line${symbol == null ? '' : ' · $symbol'}');
      excerpt(line);
    }

    for (final item in controller.parsed.program.diagnostics) {
      diagnostic(item.code, item.line, item.symbol);
    }
    final sampleReferences = <String>{};
    void samplingSources(String origin) {
      final pending = [origin];
      while (pending.isNotEmpty) {
        final name = pending.removeLast();
        if (!sampleReferences.add(name)) continue;
        final program = read.program;
        pending.addAll(program.dependencies[name] ?? const {});
        final declaration = program.declarations[name];
        final expressions = switch (declaration) {
          UiValueDeclaration(:final expression) => [expression],
          UiNodeDeclaration(:final arguments) => arguments.values.expand(
            uiArgumentExpressions,
          ),
          _ => const <UiExpression>[],
        };
        if (expressions.any(
          (expression) =>
              walkUiExpression(expression).any((entry) => entry.$1 is UiSample),
        )) {
          excerpt(declaration!.location.line);
        }
      }
    }

    // Surface error status includes evaluated values even when no visible node
    // consumes them. Use the same completed batch for their repair details.
    for (final entry in read.values.entries) {
      if (entry.value.error case final item?) {
        diagnostic(item.code, item.line, item.symbol);
      }
      if (entry.value.gaps.isNotEmpty) {
        final declaration = read.program.declarations[entry.key]!;
        for (final code in entry.value.gaps.map((gap) => gap.code).toSet()) {
          diagnostic(code, declaration.location.line, declaration.name);
        }
        samplingSources(entry.key);
      }
    }
    for (final node in read.nodes.values) {
      for (final item in node.diagnostics) {
        diagnostic(item.code, item.line, item.symbol);
      }
      if (node.gaps.isEmpty) continue;
      for (final code in node.gaps.map((gap) => gap.code).toSet()) {
        diagnostic(code, node.declaration.location.line, node.declaration.name);
      }
      samplingSources(node.declaration.name);
    }
    return UiDraftRequest(conversationId: conversationId, text: out.finish());
  }
}
