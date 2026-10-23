import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:markstream/markstream.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/app_text_selection_toolbar.dart';

class _ObservedWriter implements ClipboardWriter {
  _ObservedWriter(this.clipboard);
  final SystemClipboard clipboard;
  final completed = Completer<void>();
  @override
  Future<void> write(Iterable<DataWriterItem> items) async {
    try {
      await clipboard.write(items);
      completed.complete();
    } catch (error, stack) {
      completed.completeError(error, stack);
      rethrow;
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('message rich-copy menu writes both native clipboard formats', (
    tester,
  ) async {
    final clipboard = SystemClipboard.instance;
    expect(clipboard, isNotNull);
    final writer = _ObservedWriter(clipboard!);
    const source =
        '**Markstream clipboard QA** 中文😀 [Link](https://example.com)\n\n'
        '```dart\n  print("C46");\n```\n\n| Name | Value |\n| --- | --- |\n| Synthetic | 46 |\n\n'
        '<ol start="-3"><li>First</li><li>Second</li></ol>';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppSelectionArea(
            clipboardWriter: writer,
            child: const SingleChildScrollView(
              child: MarkstreamView(source: source, cullToViewport: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    final area = tester.widget<SelectionArea>(find.byType(SelectionArea));
    final menu =
        area.contextMenuBuilder!(
              tester.element(find.byType(SelectionArea)),
              region,
            )
            as AppTextSelectionToolbar;
    menu.buttonItems
        .singleWhere((item) => item.label == 'Copy rich text')
        .onPressed!();
    // Read only after our controlled sample has been successfully written.
    await writer.completed.future.timeout(const Duration(seconds: 30));
    final reader = await clipboard.read();
    expect(reader.canProvide(Formats.htmlText), isTrue);
    expect(reader.canProvide(Formats.plainText), isTrue);
    final html = await reader.readValue(Formats.htmlText);
    final plain = await reader.readValue(Formats.plainText);
    expect(html, contains('<strong>Markstream clipboard QA</strong>'));
    expect(html, contains('<a href="https://example.com">Link</a>'));
    expect(html, contains('<pre><code class="language-dart">'));
    expect(html, contains('<table>'));
    expect(html, contains('<ol start="-3">'));
    expect(html, contains('中文😀'));
    expect(plain, contains('Markstream clipboard QA 中文😀 Link'));
    expect(plain, contains('  print("C46");'));
    expect(plain, contains('Name\tValue\nSynthetic\t46'));
    expect(plain, contains('-3. First\n-2. Second'));
    binding.reportData = {
      'nativeRichClipboard': {
        'html': true,
        'plainText': true,
        'htmlCharacters': html!.length,
        'plainCharacters': plain!.length,
        'selection':
            'programmatic SelectAll; app menu action; native write/read',
      },
    };
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
