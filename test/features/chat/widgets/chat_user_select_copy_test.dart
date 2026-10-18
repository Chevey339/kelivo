import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/markdown_render_helpers.dart';

void main() {
  testWidgets(
    'user long press keeps message actions and opens document selection',
    (tester) async {
      const source = 'Before\n\n```text\n  alpha\n    beta\n```\n\nAfter';
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  UserProvider(preferences: createBusinessTestPreferences()),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: ChatMessageWidget(
                message: ChatMessage(
                  id: 'user-selection',
                  role: 'user',
                  conversationId: 'selection-test',
                  content: source,
                ),
                showUserAvatar: false,
                onEdit: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPressAt(markdownGlyphCenter(tester, 'Before'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete This Version'), findsOneWidget);
      await tester.tap(find.text('Select & Copy'));
      await tester.pumpAndSettle();
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      region.contextMenuButtonItems
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pumpAndSettle();
      expect(copied, source);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
