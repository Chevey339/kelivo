import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/features/chat/widgets/context_dialog.dart';
import 'package:Kelivo/features/chat/widgets/context_impact_dialog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'package:Kelivo/l10n/app_localizations_zh.dart';

void main() {
  final en = AppLocalizationsEn();
  final zh = AppLocalizationsZh();
  final operations = [
    for (final id in ['first', 'second'])
      ContextOperationMetadata(
        id: id,
        kind: ContextOperationKind.compress,
        anchorGroupId: id,
        appliedAfterGroupId: id,
        sourceGroups: [id],
        dependencies: id == 'first' ? [] : ['first'],
        createdAt: DateTime(2026),
      ),
  ];

  final primary = find.byWidgetPredicate(
    (widget) => widget is ContextDialogActionButton && widget.primary,
  );

  Future<void> pump(
    WidgetTester tester, {
    required ContextImpactKind kind,
    String? targetId,
    Set<String> affected = const {'first', 'second'},
    String locale = 'en',
    double scale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ContextImpactDialog(
          operations: operations,
          affectedIds: affected,
          kind: kind,
          targetId: targetId,
        ),
      ),
    ),
  );

  for (final kind in [
    ContextImpactKind.undo,
    ContextImpactKind.clear,
    ContextImpactKind.edit,
  ]) {
    testWidgets('$kind counts only operations after the target', (
      tester,
    ) async {
      await pump(tester, kind: kind, targetId: 'first');
      expect(
        tester.widget<ContextDialogActionButton>(primary).label,
        kind == ContextImpactKind.edit
            ? en.contextImpactSaveConfirm(1)
            : en.contextImpactConfirm(1),
      );
      await pump(tester, kind: kind, targetId: 'first', affected: {'first'});
      expect(
        tester.widget<ContextDialogActionButton>(primary).label,
        kind == ContextImpactKind.edit
            ? en.messageEditPageSave
            : en.contextImpactUndoOne,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final kind in [
    ContextImpactKind.source,
    ContextImpactKind.deleteSource,
  ]) {
    testWidgets('$kind includes every summary affected by the source', (
      tester,
    ) async {
      await pump(tester, kind: kind);
      expect(
        tester.widget<ContextDialogActionButton>(primary).label,
        en.contextImpactConfirm(2),
      );
    });
  }

  for (final locale in ['en', 'zh']) {
    testWidgets('long $locale confirmation stays readable on a small screen', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await pump(
        tester,
        kind: ContextImpactKind.undo,
        targetId: 'first',
        locale: locale,
        scale: 1.4,
      );
      await tester.pumpAndSettle();
      final label = (locale == 'en' ? en : zh).contextImpactConfirm(1);
      final text = find.descendant(of: primary, matching: find.text(label));
      expect(text.hitTestable(), findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
