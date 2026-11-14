import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/carried_original.dart';
import 'package:Kelivo/core/models/carried_selection.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/features/chat/widgets/carried_options_section.dart';
import 'package:Kelivo/features/chat/widgets/carried_messages_section.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

void main() {
  final l = AppLocalizationsEn();
  const item = CarriedOriginal(
    sourceMessageId: 'u',
    sourceGroupId: 'u',
    sourceVersion: 0,
    contentHash: 'hash',
    text: 'Keep the original requirement.',
    estimatedTokens: 40,
    reply: CarriedReply(
      messageIds: ['a'],
      text: 'The original answer.',
      estimatedTokens: 50,
    ),
  );
  const preview = CarrySelection(
    items: [item],
    totalTokens: 90,
    rows: [
      CarryRow(
        item: item,
        selected: true,
        tokens: 90,
        availableReply: itemReply,
      ),
    ],
  );
  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
  for (final width in [390.0, 900.0]) {
    testWidgets('carry controls, reply and exclusion at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var setting = const CarrySetting();
      bool? excluded;
      bool? reply;
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) => CarriedOptionsSection(
              setting: setting,
              preview: preview,
              onSetting: (v) => setState(() => setting = v),
              onExcluded: (_, v) => excluded = v,
              onReply: (_, v) => reply = v,
              onEarlier: (_) {},
            ),
          ),
        ),
      );
      expect(find.text(l.compressionCarryCountLabel), findsNothing);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is IosSwitch && w.semanticLabel == l.compressionCarryTitle,
        ),
      );
      await tester.pumpAndSettle();
      expect(setting.mode, CarryMode.count);
      expect(setting.count, 3);
      expect(find.text(item.text), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is IosSwitch && w.semanticLabel == l.compressionCarryReply,
        ),
      );
      expect(reply, true);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is IosCheckbox && w.semanticLabel == item.text,
        ),
      );
      expect(excluded, true);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('untouched Codex remains unset and compact is explanatory only', (
    tester,
  ) async {
    var changed = false;
    Widget section(bool server) => CarriedOptionsSection(
      setting: const CarrySetting(),
      preview: preview,
      codex: true,
      serverKeeps: server,
      onSetting: (_) => changed = true,
      onExcluded: (_, _) {},
      onReply: (_, _) {},
      onEarlier: (_) {},
    );
    await tester.pumpWidget(app(section(false)));
    expect(
      tester
          .widget<IosSwitch>(
            find.byWidgetPredicate(
              (w) =>
                  w is IosSwitch && w.semanticLabel == l.compressionCarryTitle,
            ),
          )
          .value,
      true,
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, false);
    expect(field.controller!.text, '1');
    expect(changed, false);
    expect(find.textContaining('64k'), findsNothing);
    await tester.pumpWidget(app(section(true)));
    expect(find.text(l.compressionCarryServerKeeps), findsOneWidget);
    expect(find.byType(IosSwitch), findsNothing);
  });
  testWidgets('invalid count blocks submission until corrected or set to all', (
    tester,
  ) async {
    var setting = const CarrySetting(mode: CarryMode.count, count: 2);
    var valid = true;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => CarriedOptionsSection(
            setting: setting,
            preview: preview,
            onSetting: (v) => setState(() => setting = v),
            onValidity: (v) => valid = v,
            onExcluded: (_, _) {},
            onReply: (_, _) {},
            onEarlier: (_) {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '10001');
    expect(valid, false);
    expect(setting.count, 2);
    await tester.enterText(find.byType(TextField), '7');
    expect(valid, true);
    expect(setting.count, 7);
    await tester.enterText(find.byType(TextField), '');
    expect(valid, false);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is IosCheckbox && w.semanticLabel == l.compressionCarryAll,
      ),
    );
    await tester.pumpAndSettle();
    expect(valid, true);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
  });
  testWidgets('details edit freezes a copy and rejects empty text', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var op =
        ContextOperation(
          id: 'op',
          kind: ContextOperationKind.compress,
          anchorGroupId: 'u',
          appliedAfterGroupId: 'u',
          sourceGroups: ['u'],
          dependencies: [],
          createdAt: DateTime(2026),
          summary: 'summary',
        ).withCarried(
          const CarriedOriginals(
            setting: CarrySetting(mode: CarryMode.count),
            items: [item],
          ),
        );
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => CarriedMessagesSection(
            operation: op,
            sourceIds: const {'u'},
            onSave: (value) async {
              setState(() => op = op.withCarried(value));
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text(l.assistantSettingsEditButton).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, '');
    await tester.pump();
    expect(find.text(l.contextCarriedEmpty), findsOneWidget);
    await tester.enterText(
      find.byType(EditableText).first,
      'Edited requirement.',
    );
    await tester.pump();
    await tester.tap(find.text(l.messageEditPageSave));
    await tester.pumpAndSettle();
    expect(op.carried!.items.single.effectiveText, 'Edited requirement.');
    expect(op.carried!.items.single.text, item.text);
    expect(find.text(l.contextDetailEdited), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('historical carried details expose only copying', (tester) async {
    final op =
        ContextOperation(
          id: 'op',
          kind: ContextOperationKind.compress,
          anchorGroupId: 'u',
          appliedAfterGroupId: 'u',
          sourceGroups: ['u'],
          dependencies: [],
          createdAt: DateTime(2026),
          revoked: true,
        ).withCarried(
          const CarriedOriginals(
            setting: CarrySetting(mode: CarryMode.count),
            items: [item],
          ),
        );
    await tester.pumpWidget(app(CarriedMessagesSection(operation: op)));
    expect(find.text(l.assistantSettingsEditButton), findsNothing);
    expect(find.text(l.contextCarriedRemove), findsNothing);
    expect(find.text(l.assistantSettingsCopyButton), findsNWidgets(2));
  });
}

const itemReply = CarriedReply(
  messageIds: ['a'],
  text: 'The original answer.',
  estimatedTokens: 50,
);
