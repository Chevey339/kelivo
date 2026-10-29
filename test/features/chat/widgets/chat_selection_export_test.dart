import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/features/chat/widgets/message_export_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

Future<void> _openExport(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showChatExportSheet(
              context,
              conversation: Conversation(id: 'chat', title: 'Selection'),
              selectedMessages: [
                ChatMessage(
                  id: 'm',
                  conversationId: 'chat',
                  role: 'assistant',
                  content: 'Selected answer',
                ),
              ],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'export adapts to platform and keeps dependent thinking options',
    (tester) async {
      await _openExport(tester);
      final desktop = {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);
      expect(find.byType(Dialog), desktop ? findsOneWidget : findsNothing);
      expect(find.byType(BottomSheet), desktop ? findsNothing : findsOneWidget);
      expect(find.text('Markdown'), findsOneWidget);
      expect(find.text('Plain Text'), findsOneWidget);
      expect(find.text('Export as Image'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Show thinking content'),
        120,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      await tester.pumpAndSettle();
      IosSwitch tools() =>
          tester.widget<IosSwitch>(find.byType(IosSwitch).first);
      IosSwitch thinking() =>
          tester.widget<IosSwitch>(find.byType(IosSwitch).last);
      expect(tools().value, isFalse);
      expect(thinking().onChanged, isNull);
      await tester.tap(find.byType(IosSwitch).first);
      await tester.pumpAndSettle();
      expect(tools().value, isTrue);
      expect(thinking().onChanged, isNotNull);
      await tester.tap(find.byType(IosSwitch).last);
      await tester.pumpAndSettle();
      expect(thinking().value, isTrue);
      await tester.tap(find.byType(IosSwitch).first);
      await tester.pumpAndSettle();
      expect(thinking().value, isFalse);
      expect(thinking().onChanged, isNull);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Export Format'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  for (final size in [
    const Size(320, 568),
    const Size(640, 360),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'export remains scrollable at $size with large text',
      (tester) async {
        await _openExport(tester, size: size, textScale: 2);
        expect(find.text('Export Format'), findsOneWidget);
        if (size.width >= 1280 ||
            defaultTargetPlatform == TargetPlatform.macOS) {
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.byType(Dialog), findsOneWidget);
        }
        await tester.scrollUntilVisible(
          find.text('Show thinking content'),
          120,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .last,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
    );
  }
}
