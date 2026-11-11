import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/message_edit_dialog.dart';
import 'package:Kelivo/desktop/select_copy_dialog.dart';
import 'package:Kelivo/features/chat/models/message_edit_result.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../support/business_test_harness.dart';

void main() {
  for (final locale in [const Locale('en'), const Locale('zh')]) {
    for (final copy in [false, true]) {
      testWidgets('360px message ${copy ? 'copy' : 'edit'} dialog on $locale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 640);
        addTearDown(tester.view.reset);
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        MessageEditResult? saved;
        late AppLocalizations l10n;
        final message = ChatMessage(
          id: 'm',
          conversationId: 'c',
          role: 'user',
          content: 'Original message',
        );
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
            child: MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    l10n = AppLocalizations.of(context)!;
                    return TextButton(
                      onPressed: () async {
                        if (copy) {
                          await showSelectCopyDesktopDialog(
                            context,
                            message: message,
                          );
                        } else {
                          saved = await showMessageEditDesktopDialog(
                            context,
                            message: message,
                          );
                        }
                      },
                      child: const Text('Open'),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (copy) {
          await tester.tap(find.text(l10n.selectCopyPageCopyAll));
          await tester.pumpAndSettle();
          expect(copied, 'Original message');
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
        } else {
          await tester.enterText(find.byType(TextField), 'Edited draft');
          tester.view.physicalSize = const Size(1100, 700);
          await tester.pumpAndSettle();
          tester.view.physicalSize = const Size(360, 640);
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.messageEditPageSave));
          await tester.pumpAndSettle();
          expect(saved?.content, 'Edited draft');
          expect(saved?.shouldSend, isFalse);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
