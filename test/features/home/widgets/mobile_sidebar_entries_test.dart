import 'package:Kelivo/core/models/sidebar_layout.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/widgets/sidebar_user_bar.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/features/home/widgets/mobile_sidebar_entries.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/sidebar_entry_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  testWidgets('More follows entry visibility and the customization shortcut', (
    tester,
  ) async {
    late SettingsProvider settings;
    await tester.runAsync(() async {
      settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      await settings.setMobileSidebarEntries(const {
        SidebarEntry.history: SidebarVisibility.more,
        SidebarEntry.translate: SidebarVisibility.hidden,
      });
    });
    addTearDown(settings.dispose);
    final opened = <SidebarEntry>[];
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: MobileSidebarEntries(onOpen: opened.add)),
        ),
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MobileSidebarEntries)),
    )!;
    expect(find.text(l10n.sidebarMore), findsOneWidget);
    expect(find.text(l10n.sideDrawerHistory), findsNothing);
    await tester.tap(find.text(l10n.sidebarMore));
    await tester.pumpAndSettle();
    expect(find.text(l10n.sidebarCustomize), findsOneWidget);
    expect(find.text(l10n.desktopNavTranslateTooltip), findsNothing);
    await tester.tap(find.text(l10n.sideDrawerHistory));
    expect(opened, [SidebarEntry.history]);

    await tester.runAsync(() async {
      await settings.setShowSidebarCustomizeInMore(false);
      await settings.setMobileSidebarEntries(const {
        SidebarEntry.history: SidebarVisibility.show,
        SidebarEntry.translate: SidebarVisibility.hidden,
      });
    });
    await tester.pumpAndSettle();
    expect(find.text(l10n.sidebarMore), findsNothing);
    expect(find.text(l10n.sidebarCustomize), findsNothing);
    expect(find.text(l10n.sideDrawerHistory), findsOneWidget);
    await tester.longPress(find.text(l10n.sideDrawerHistory));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text(SidebarVisibility.hidden.menuLabel(l10n)));
    await tester.pumpAndSettle();
    expect(
      settings.mobileSidebarEntries[SidebarEntry.history],
      SidebarVisibility.hidden,
    );
    expect(find.text(l10n.sideDrawerHistory), findsNothing);
  });
  testWidgets('a 240px user bar keeps Settings reachable with overflow', (
    tester,
  ) async {
    final user = UserProvider(preferences: createBusinessTestPreferences());
    addTearDown(user.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: user,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 240,
                child: SidebarUserBar(
                  name: 'Psyche',
                  embedded: false,
                  entries: const {
                    SidebarEntry.history: SidebarVisibility.more,
                    SidebarEntry.translate: SidebarVisibility.show,
                  },
                  onOpen: (_) {},
                  onEditAvatar: () {},
                  onEditName: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(SidebarUserBar));
    expect(
      bar.contains(tester.getCenter(find.byIcon(Lucide.Settings))),
      isTrue,
    );
    expect(find.byIcon(Lucide.Ellipsis), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
