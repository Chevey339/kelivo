import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/workspace/widgets/desktop_workspaces_view.dart';
import 'package:Kelivo/features/workspace/workspace_navigation.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  for (final (width, scale) in [(420.0, 1.0), (660.0, 1.5), (1000.0, 1.0)]) {
    testWidgets(
      'desktop environment is reachable before creating a workspace ($width)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        final original = WorkspaceNavigation.onOpenEnvironmentPage;
        var opened = false;
        WorkspaceNavigation.onOpenEnvironmentPage = (_) => opened = true;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          WorkspaceNavigation.onOpenEnvironmentPage = original;
        });
        try {
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('ru'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: DesktopWorkspacesView(
                  workspaces: const [],
                  onCreate: () async => null,
                  onMore: (_, _) {},
                ),
              ),
            ),
          );
          await tester.tap(
            find.byKey(const ValueKey('workspaces-environment')),
          );
          await tester.pump();
          expect(opened, isTrue);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
