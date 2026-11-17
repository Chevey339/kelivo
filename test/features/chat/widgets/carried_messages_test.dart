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
import 'package:Kelivo/shared/widgets/ios_text_button.dart';

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
              onReplies: (_, v) => reply = v,
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
      onReplies: (_, _) {},
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
    expect(find.byType(TextField), findsNothing);
    expect(find.text(l.compressionCarryAll), findsOneWidget);
    expect(find.text(l.compressionCarryPreview(1, 1, '90')), findsOneWidget);
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
            onReplies: (_, _) {},
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
    await tester.tap(find.text(l.compressionCarryAll));
    await tester.pumpAndSettle();
    expect(valid, true);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets(
    'attachment-only rows show images or filenames, and a selected reply shows its text',
    (tester) async {
      final withoutText = item.copyWith(text: '\n   ', hasAttachments: true);
      const png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      final photo = CarryRow(
        item: withoutText,
        selected: true,
        tokens: 4000,
        imageUris: const [png, png, png, png],
        attachmentCount: 4,
        availableReply: itemReply,
      );
      final file = CarryRow(
        item: withoutText.copyWith(sourceMessageId: 'doc'),
        messageText: '',
        fileNames: const ['Notes.pdf'],
        selected: true,
        tokens: 40,
        attachmentCount: 1,
      );
      final selection = CarrySelection(
        items: [photo.item, file.item],
        rows: [photo, file],
        totalTokens: 4040,
      );
      final replies = <String>{};
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) => CarriedOptionsSection(
              setting: const CarrySetting(mode: CarryMode.count),
              preview: selection,
              replies: replies,
              onSetting: (_) {},
              onExcluded: (_, _) {},
              onReplies: (ids, v) => setState(
                () => v ? replies.addAll(ids) : replies.removeAll(ids),
              ),
              onEarlier: (_) {},
            ),
          ),
        ),
      );
      expect(find.text(l.compressionCarryImageCount(4)), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(4));
      expect(find.text('Notes.pdf'), findsOneWidget);
      expect(find.text(itemReply.text), findsNothing);
      final toggle = find.byWidgetPredicate(
        (w) => w is IosSwitch && w.semanticLabel == l.compressionCarryReply,
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text(itemReply.text), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'selecting and clearing replies covers collapsed rows and allows individual changes',
    (tester) async {
      final rows = List.generate(
        54,
        (i) => CarryRow(
          item: item.copyWith(
            sourceMessageId: 'u$i',
            text: 'Message $i',
            removeReply: true,
          ),
          selected: i != 1,
          tokens: 40,
          availableReply: i == 3 ? null : itemReply,
          replyInRetained: i == 2,
        ),
      );
      final replies = {'u0'};
      final excluded = {'u1'};
      var edits = 0;
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) => CarriedOptionsSection(
              setting: const CarrySetting(mode: CarryMode.count, count: 54),
              preview: CarrySelection(rows: rows),
              replies: replies,
              excluded: excluded,
              onSetting: (_) => fail('Changed the retention mode'),
              onEarlier: (_) => fail('Changed the range'),
              onExcluded: (_, _) => fail('Changed a user selection'),
              onReplies: (ids, included) => setState(() {
                edits++;
                if (included) {
                  replies.addAll(ids);
                } else {
                  replies.removeAll(ids);
                }
              }),
            ),
          ),
        ),
      );
      final selectAll = find.widgetWithText(
        IosTextButton,
        l.compressionCarrySelectAllReplies,
      );
      final clearAll = find.widgetWithText(
        IosTextButton,
        l.compressionCarryDeselectAllReplies,
      );
      expect(find.text('Message 53'), findsNothing);
      expect(clearAll, findsOneWidget);
      await tester.ensureVisible(selectAll);
      await tester.tap(selectAll);
      await tester.pumpAndSettle();
      expect(edits, 1);
      expect(replies, {'u0', for (var i = 4; i < 54; i++) 'u$i'});
      expect(selectAll, findsNothing);
      await tester.tap(clearAll);
      await tester.pumpAndSettle();
      expect(edits, 2);
      expect(replies, isEmpty);
      expect(excluded, {'u1'});
      expect(clearAll, findsNothing);
      await tester.tap(selectAll);
      await tester.pumpAndSettle();

      final more = find.text(l.compressionCarryMoreRows(4));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      final lastReply = find
          .byWidgetPredicate(
            (w) => w is IosSwitch && w.semanticLabel == l.compressionCarryReply,
          )
          .last;
      expect(tester.widget<IosSwitch>(lastReply).value, isTrue);
      await tester.ensureVisible(lastReply);
      await tester.tap(lastReply);
      await tester.pumpAndSettle();
      expect(edits, 4);
      expect(replies.contains('u53'), isFalse);
      expect(replies.length, 50);
      expect(tester.widget<IosTextButton>(selectAll).onPressed, isNotNull);
      await tester.ensureVisible(clearAll);
      await tester.tap(clearAll);
      await tester.pumpAndSettle();
      expect(replies, isEmpty);
    },
  );
  testWidgets(
    'a reply pair outside the budget is editable and excluded from the preview',
    (tester) async {
      const result = CarrySelection(
        rows: [
          CarryRow(
            item: item,
            selected: true,
            tokens: 40,
            availableReply: itemReply,
            replyDoesNotFit: true,
          ),
        ],
        reachedBudget: true,
        notFit: 1,
      );
      final replies = {'u', 'older-outside-budget'};
      await tester.pumpWidget(
        app(
          CarriedOptionsSection(
            setting: const CarrySetting(mode: CarryMode.all),
            preview: result,
            replies: replies,
            onSetting: (_) {},
            onEarlier: (_) {},
            onExcluded: (_, _) {},
            onReplies: (ids, included) {
              expect(included, isFalse);
              replies.removeAll(ids);
            },
          ),
        ),
      );
      expect(find.text(l.compressionCarryPreview(0, 0, '0')), findsOneWidget);
      expect(find.text(l.compressionCarryPairNotFit), findsOneWidget);
      expect(find.text(itemReply.text), findsNothing);
      final toggle = tester.widget<IosSwitch>(
        find.byWidgetPredicate(
          (w) => w is IosSwitch && w.semanticLabel == l.compressionCarryReply,
        ),
      );
      expect(toggle.value, isTrue);
      expect(toggle.onChanged, isNotNull);
      await tester.tap(find.text(l.compressionCarryDeselectAllReplies));
      expect(replies, isEmpty);
    },
  );
  testWidgets(
    'pending reply choices update totals immediately only for a fixed shortlist',
    (tester) async {
      const row = CarryRow(
        item: item,
        selected: true,
        tokens: 40,
        availableReply: itemReply,
      );
      const result = CarrySelection(
        items: [item],
        rows: [row],
        totalTokens: 40,
      );
      Widget section(CarryMode mode) => app(
        CarriedOptionsSection(
          setting: CarrySetting(mode: mode),
          preview: result,
          loading: true,
          replies: const {'u'},
          excluded: const {},
          onSetting: (_) {},
          onEarlier: (_) {},
          onReplies: (_, _) {},
          onExcluded: (_, _) {},
        ),
      );
      await tester.pumpWidget(section(CarryMode.count));
      expect(
        find.text(
          l.compressionCarryPreview(
            1,
            1,
            (40 + itemReply.estimatedTokens).toString(),
          ),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(section(CarryMode.all));
      expect(find.text(l.contextUsageStateComputing), findsOneWidget);
      expect(
        tester
            .widget<IosTextButton>(
              find.widgetWithText(
                IosTextButton,
                l.compressionCarryDeselectAllReplies,
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text(item.text), findsOneWidget);
    },
  );
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
