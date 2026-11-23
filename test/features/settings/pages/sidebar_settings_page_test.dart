import 'package:Kelivo/core/models/sidebar_layout.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/pages/sidebar_settings_page.dart';
import 'package:Kelivo/features/settings/widgets/sidebar_entries_editor.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  testWidgets('moving blocks shows the drop line and Escape cancels the move', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late SettingsProvider settings;
    await tester.runAsync(() async {
      settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      await settings.setMobileSidebarLayout(SidebarPreset.navigation.layout);
    });
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: SidebarSettingsPage(),
        ),
      ),
    );
    final handles = find.descendant(
      of: find.byType(SidebarReorderList<SidebarBlock>),
      matching: find.byIcon(Lucide.GripVertical),
    );
    await tester.ensureVisible(handles.last);
    await tester.pumpAndSettle();
    final original = settings.mobileSidebarLayout.order;
    final dropLine = find.byKey(const ValueKey('sidebar-drop-indicator'));
    final drag = await tester.startGesture(tester.getCenter(handles.last));
    await drag.moveBy(const Offset(0, -110));
    await tester.pumpAndSettle();
    expect(dropLine, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await drag.up();
    await tester.pumpAndSettle();
    expect(dropLine, findsNothing);
    expect(settings.mobileSidebarLayout.order, original);

    final cancelled = await tester.startGesture(tester.getCenter(handles.last));
    await cancelled.moveBy(const Offset(0, -110));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(dropLine, findsNothing);
    expect(settings.mobileSidebarLayout.order, original);
    await tester.tap(handles.last);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      settings.mobileSidebarLayout.isBelowConversations(SidebarBlock.user),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
