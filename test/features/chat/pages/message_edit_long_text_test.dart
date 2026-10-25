import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/models/message_edit_result.dart';
import 'package:Kelivo/features/chat/pages/message_edit_page.dart';
import 'package:Kelivo/features/chat/widgets/message_edit_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  final source = List.generate(
    1200,
    (i) => '$i 中文 **long message**',
  ).join('\n');
  for (final mode in ['page', 'sheet-save', 'sheet-send', 'sheet-cancel']) {
    testWidgets('$mode preserves edits outside the visible region', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final message = ChatMessage(
        id: 'edit',
        role: 'user',
        conversationId: 'edit',
        content: source,
      );
      Object? result;
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = mode == 'page'
                        ? await Navigator.of(context).push<String>(
                            MaterialPageRoute(
                              builder: (_) => MessageEditPage(message: message),
                            ),
                          )
                        : await showMessageEditSheet(context, message: message);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final lines = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .controller!;
      lines.selection = CodeLineSelection.collapsed(
        index: lines.codeLines.length - 1,
        offset: lines.codeLines.last.length,
      );
      lines.replaceSelection('\n末尾完整保存');
      lines.selection = const CodeLineSelection.collapsed(
        index: 513,
        offset: 4,
      );
      lines.replaceSelection('改');
      final offset = source.indexOf('513 中文') + 4;
      final expected = '${source.replaceRange(offset, offset, '改')}\n末尾完整保存';
      expect(
        tester
            .widget<LongMessageEditor>(find.byType(LongMessageEditor))
            .controller
            .text,
        expected,
      );
      expect(message.content, source);
      await tester.pump();
      if (mode == 'sheet-cancel') {
        Navigator.of(tester.element(find.byType(LongMessageEditor))).pop();
      } else {
        await tester.tap(
          find.text(mode == 'sheet-send' ? 'Save & Send' : 'Save'),
        );
      }
      await tester.pumpAndSettle();
      if (mode == 'sheet-cancel') {
        expect(result, isNull);
      } else if (mode == 'page') {
        expect(result, expected);
      } else {
        final saved = result! as MessageEditResult;
        expect(saved.content, expected);
        expect(saved.shouldSend, mode == 'sheet-send');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
