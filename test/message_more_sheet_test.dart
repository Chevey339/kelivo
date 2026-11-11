import 'package:flutter/foundation.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'support/business_test_harness.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/chat/widgets/message_more_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

ChatMessage _message() {
  return ChatMessage(
    id: 'message-1',
    role: 'assistant',
    content: 'hello',
    conversationId: 'conversation-1',
  );
}

Future<void> _openMoreSheet(
  WidgetTester tester, {
  required bool canDeleteAllVersions,
  bool canCreateBranch = true,
  bool canSetContextStart = false,
  bool isContextStart = false,
  double textScale = 1,
  Locale? locale,
  ValueChanged<MessageMoreAction?>? onSelected,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
      child: MaterialApp(
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showMessageMoreSheet(
                    context,
                    _message(),
                    canDeleteAllVersions: canDeleteAllVersions,
                    canCreateBranch: canCreateBranch,
                    canSetContextStart: canSetContextStart,
                    isContextStart: isContextStart,
                  ).then((action) => onSelected?.call(action));
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  });
  testWidgets(
    'compact message menu keeps every action with accessible click targets',
    (tester) async {
      final desktop = {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = desktop
          ? const Size(1000, 800)
          : const Size(390, 844);
      addTearDown(tester.view.reset);
      MessageMoreAction? selected;
      await _openMoreSheet(
        tester,
        canDeleteAllVersions: false,
        canSetContextStart: true,
        locale: const Locale('zh'),
        onSelected: (action) => selected = action,
      );
      final l10n = AppLocalizations.of(tester.element(find.text('open')))!;
      expect(find.text(l10n.contextFixedStartDescription), findsNothing);
      expect(find.text(l10n.branchInheritNote), findsNothing);
      expect(find.byType(Divider), findsNWidgets(3));
      final rows = find.byType(IosCardPress);
      expect(rows, findsNWidgets(8));
      final bounds = [
        for (final element in rows.evaluate())
          tester.getRect(find.byWidget(element.widget)),
      ];
      expect(
        bounds.last.bottom - bounds.first.top,
        lessThanOrEqualTo(desktop ? 330 : 400),
      );
      for (final rect in bounds) {
        expect(rect.height, greaterThanOrEqualTo(desktop ? 36 : 44));
      }
      if (desktop) expect(bounds.first.width, lessThan(320));
      await tester.tap(find.text(l10n.messageMoreSheetDelete));
      await tester.pumpAndSettle();
      expect(selected, MessageMoreAction.deleteCurrentVersion);
      expect(tester.takeException(), isNull);
    },
    variant: platforms,
  );

  testWidgets(
    'compact menu keeps destructive actions reachable with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.reset);
      MessageMoreAction? selected;
      await _openMoreSheet(
        tester,
        canDeleteAllVersions: true,
        canSetContextStart: true,
        textScale: 2,
        onSelected: (action) => selected = action,
      );
      await tester.ensureVisible(find.text('Delete All Versions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete All Versions'));
      await tester.pumpAndSettle();
      expect(selected, MessageMoreAction.deleteAllVersions);
      expect(tester.takeException(), isNull);
    },
    variant: platforms,
  );

  for (final pinned in [false, true]) {
    testWidgets(
      'context start menu action: pinned=$pinned',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        MessageMoreAction? selected;
        await _openMoreSheet(
          tester,
          canDeleteAllVersions: false,
          canSetContextStart: true,
          isContextStart: pinned,
          onSelected: (action) => selected = action,
        );
        final label = pinned
            ? 'Cancel fixed context start'
            : 'Start context here';
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(
          selected,
          pinned
              ? MessageMoreAction.cancelContextStart
              : MessageMoreAction.setContextStart,
        );
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }),
    );
  }

  testWidgets(
    'one menu entry selects messages for every batch action',
    (tester) async {
      MessageMoreAction? selected;
      await _openMoreSheet(
        tester,
        canDeleteAllVersions: false,
        onSelected: (action) => selected = action,
      );
      expect(find.text('Share'), findsNothing);
      expect(find.text('Select Messages'), findsOneWidget);
      await tester.tap(find.text('Select Messages'));
      await tester.pumpAndSettle();
      expect(selected, MessageMoreAction.selectMessages);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets('多版本消息菜单显示删除全部版本', (tester) async {
    await _openMoreSheet(tester, canDeleteAllVersions: true);

    expect(find.text('Select Messages'), findsOneWidget);
    expect(find.text('Create Branch'), findsOneWidget);
    expect(find.text('Delete This Version'), findsOneWidget);
    expect(find.text('Delete All Versions'), findsOneWidget);
  });

  testWidgets('单版本消息菜单不显示删除全部版本', (tester) async {
    await _openMoreSheet(tester, canDeleteAllVersions: false);

    expect(find.text('Select Messages'), findsOneWidget);
    expect(find.text('Delete This Version'), findsOneWidget);
    expect(find.text('Delete All Versions'), findsNothing);
  });

  testWidgets('临时会话消息菜单不显示创建分支', (tester) async {
    await _openMoreSheet(
      tester,
      canDeleteAllVersions: false,
      canCreateBranch: false,
    );

    expect(find.text('Create Branch'), findsNothing);
  });
}
