import '../../../support/business_test_harness.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/token_display_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final layout in [
    (width: 343.0, selectionGutter: 0.0, textScale: 1.0, tokens: 2705),
    (width: 390.0, selectionGutter: 44.0, textScale: 1.0, tokens: 2705),
    (width: 320.0, selectionGutter: 44.0, textScale: 2.0, tokens: 987654321),
    (width: 260.0, selectionGutter: 44.0, textScale: 1.0, tokens: null),
    (width: 1024.0, selectionGutter: 44.0, textScale: 2.0, tokens: 987654321),
  ]) {
    testWidgets(
      'message actions fit $layout and remain interactive',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var copies = 0;
        var moreActions = 0;
        var previousVersions = 0;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    TtsProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(create: (_) => ToolApprovalService()),
              ChangeNotifierProvider(
                create: (_) => AskUserInteractionService(),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(layout.textScale)),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: layout.width,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.only(left: layout.selectionGutter),
                        child: ChatMessageWidget(
                          message: ChatMessage(
                            id: 'long-response',
                            role: 'assistant',
                            conversationId: 'chat',
                            content:
                                'A response with multiple versions and token statistics.',
                            totalTokens: layout.tokens,
                            promptTokens: 2000,
                            completionTokens: 705,
                          ),
                          showModelIcon: false,
                          versionIndex: 1,
                          versionCount: 2,
                          onCopy: () => copies++,
                          onMore: () => moreActions++,
                          onPrevVersion: () => previousVersions++,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final footer = find.byKey(const ValueKey('assistant-actions'));
        await tester.ensureVisible(footer);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(footer);
        final buttons = find.descendant(
          of: footer,
          matching: find.byType(IosIconButton),
        );
        for (final button in buttons.evaluate()) {
          final rect = tester.getRect(find.byWidget(button.widget));
          expect(rect.left, greaterThanOrEqualTo(bounds.left));
          expect(rect.right, lessThanOrEqualTo(bounds.right));
        }
        if (layout.tokens != null) {
          final stats = tester.getRect(find.byType(TokenDisplayWidget));
          expect(stats.left, greaterThanOrEqualTo(bounds.left));
          expect(stats.right, lessThanOrEqualTo(bounds.right));
          if (layout.width == 1024) {
            // Wide layouts retain the compact row and right-aligned statistics.
            expect(
              stats.center.dy,
              closeTo(tester.getCenter(find.byIcon(Lucide.Copy)).dy, 0.1),
            );
            expect(stats.right, closeTo(bounds.right, 0.1));
          }
        }
        expect(find.text('2/2'), findsOneWidget);
        await tester.tap(find.byIcon(Lucide.Copy));
        await tester.tap(find.byIcon(Lucide.Ellipsis));
        await tester.tap(find.byIcon(Lucide.ChevronLeft));
        expect(copies, 1);
        expect(moreActions, 1);
        expect(previousVersions, 1);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }),
    );
  }
}
