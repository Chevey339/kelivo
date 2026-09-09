import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_status_chip.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import '../../../support/business_test_harness.dart';

void main() {
  Future<EnvironmentProvider> createEnv(
    WidgetTester tester,
    EnvironmentState state,
  ) async {
    final env = await tester.runAsync(() async {
      final created = EnvironmentProvider(
        preferences: createBusinessTestPreferences(),
      );
      await created.loaded;
      await created.setState(state);
      return created;
    });
    return env!;
  }

  Future<AppLocalizations> pumpChip(
    WidgetTester tester,
    EnvironmentProvider env, {
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<EnvironmentProvider>.value(
        value: env,
        child: MaterialApp(
          theme: buildLightTheme(null),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: EnvironmentStatusChip(onTap: onTap)),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
  }

  testWidgets('hidden when ready', (tester) async {
    final env = await createEnv(
      tester,
      const EnvironmentState(phase: EnvironmentPhase.ready),
    );
    await pumpChip(tester, env);
    expect(find.byKey(EnvironmentStatusChip.chipKey), findsNothing);
  });

  testWidgets('notInstalled shows Install sandbox', (tester) async {
    final env = await createEnv(tester, const EnvironmentState());
    final l10n = await pumpChip(tester, env);
    expect(find.text(l10n.workspaceEnvChipInstall), findsOneWidget);
  });

  testWidgets('installing shows percent', (tester) async {
    final env = await createEnv(
      tester,
      const EnvironmentState(
        phase: EnvironmentPhase.downloading,
        progress: 0.43,
      ),
    );
    final l10n = await pumpChip(tester, env);
    expect(find.text(l10n.workspaceEnvChipInstalling(43)), findsOneWidget);
  });

  testWidgets('error and needsRestart labels', (tester) async {
    final env = await createEnv(
      tester,
      const EnvironmentState(phase: EnvironmentPhase.error),
    );
    final l10n = await pumpChip(tester, env);
    expect(find.text(l10n.workspaceEnvChipError), findsOneWidget);

    await tester.runAsync(() {
      return env.setState(
        const EnvironmentState(phase: EnvironmentPhase.needsRestart),
      );
    });
    await tester.pump();
    expect(find.text(l10n.workspaceEnvChipRestart), findsOneWidget);
  });

  testWidgets('tap invokes callback', (tester) async {
    var taps = 0;
    final env = await createEnv(tester, const EnvironmentState());
    await pumpChip(tester, env, onTap: () => taps += 1);
    await tester.tap(find.byKey(EnvironmentStatusChip.chipKey));
    expect(taps, 1);
  });
}
