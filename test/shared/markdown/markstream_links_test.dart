import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'markstream_adapters_test.dart' show host;

class _Launcher extends UrlLauncherPlatform {
  final launched = <String>[];
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

Offset _labelCenter(String label) {
  RenderParagraph? paragraph;
  void visit(RenderObject object) {
    if (object is RenderParagraph &&
        object.text.toPlainText().contains(label)) {
      paragraph = object;
    }
    object.visitChildren(visit);
  }

  for (final view in RendererBinding.instance.renderViews) {
    visit(view);
  }
  final p = paragraph!;
  final start = p.text.toPlainText().indexOf(label);
  final rect = p
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + 1),
      )
      .first
      .toRect();
  return p.localToGlobal(rect.center);
}

void main() {
  testWidgets('external links open their URL from a cached paragraph', (
    tester,
  ) async {
    final previous = UrlLauncherPlatform.instance, launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    await tester.pumpWidget(
      host(
        const MarkdownWithCodeHighlight(
          text: '[external](https://example.com/path?a=1)',
          streaming: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(UrlLauncherPlatform.instance, same(launcher));
    await tester.tapAt(_labelCenter('external'));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['https://example.com/path?a=1']);
  });
  testWidgets('workspace links stay inside Kelivo in text and table cells', (
    tester,
  ) async {
    final previous = UrlLauncherPlatform.instance, launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    const link = '[daily_sign.py](kelivo://workspace/shenyu/daily_sign.py)';
    for (final source in [link, '| File |\n| --- |\n| $link |']) {
      await tester.pumpWidget(
        host(
          MarkdownWithCodeHighlight(
            text: source,
            conversationId: 'unavailable-conversation',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(_labelCenter('daily_sign.py'));
      await tester.pump();
      expect(find.text('File not available'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(launcher.launched, isEmpty);
      expect(tester.takeException(), isNull);
    }
  });
}
