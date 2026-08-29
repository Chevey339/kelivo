import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/restore_failure_screen.dart';

/// Stands in for the platform channel, which never answers under `flutter
/// test` and would otherwise leave a pending timeout timer behind.
Future<({String? version, String? build})> stubVersion() async =>
    (version: '1.2.4', build: '68');

StartupFailureReport reportFor(
  Object error, {
  StartupFailureStage stage = StartupFailureStage.databaseAdmission,
}) => StartupFailureReport.capture(stage: stage, error: error);

Widget wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);

/// The screen scrolls, and a lazy list only builds what fits. A tall surface
/// keeps every section built so the finders below mean what they say.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Lets the screen's real file I/O finish. Each `await` on real I/O resumes as
/// a microtask in the test's fake zone, which only drains on a pump, so the two
/// have to alternate until the chain is done.
Future<void> settleDiagnostics(WidgetTester tester, {int rounds = 12}) async {
  for (var round = 0; round < rounds; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('explains fail-closed startup without opening business UI', (
    tester,
  ) async {
    useTallSurface(tester);
    var restartCalls = 0;
    await tester.pumpWidget(
      wrap(
        RestoreFailureScreen(
          report: reportFor(
            StateError('restore_startup_receipt'),
            stage: StartupFailureStage.restoreGate,
          ),
          restart: () async => restartCalls++,
          appVersionLoader: stubVersion,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restore requires attention'), findsOneWidget);
    expect(find.textContaining('chat data was not opened'), findsOneWidget);
    expect(find.text('Restart Kelivo'), findsOneWidget);

    // The failure itself is on screen, not just a type name.
    expect(
      find.textContaining('StateError: restore_startup_receipt'),
      findsOneWidget,
    );
    expect(find.text('restore_startup_receipt'), findsOneWidget);
    expect(find.text('Restore gate'), findsOneWidget);

    await tester.tap(find.text('Restart Kelivo'));
    await tester.pump();
    expect(restartCalls, 1);
  });

  testWidgets('shows the whole report behind one disclosure', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrap(
        RestoreFailureScreen(
          report: reportFor(StateError('database_schema_version')),
          restart: () async {},
          appVersionLoader: stubVersion,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('== error =='), findsNothing);
    await tester.tap(find.text('Show technical details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('== error =='), findsOneWidget);
    expect(find.textContaining('stage: database_admission'), findsOneWidget);
  });

  testWidgets('explains an occupied business lease with a useful action', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrap(
        RestoreFailureScreen(
          report: reportFor(
            StateError('RestoreBusinessLeaseUnavailable'),
            stage: StartupFailureStage.restoreGate,
          ),
          restart: () async {},
          appVersionLoader: stubVersion,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kelivo is already running'), findsOneWidget);
    expect(find.textContaining('another app process'), findsOneWidget);
    expect(find.text('Restart Kelivo'), findsOneWidget);
    // A lease conflict is not a data problem, so no file-level actions.
    expect(find.text('Danger zone'), findsNothing);
  });

  group('with a data directory', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_restore_failure_screen_',
      );
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        wrap(
          RestoreFailureScreen(
            report: reportFor(StateError('database_identity_mismatch')),
            restart: () async {},
            appDataDirectory: directory,
            appVersionLoader: stubVersion,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers salvage before repair and hides reset', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Export a copy of my data'), findsOneWidget);
      expect(find.text('Check database integrity'), findsOneWidget);
      expect(find.text('Repair and restart'), findsOneWidget);
      // Reset must never be one stray tap away.
      expect(find.text('Reset data'), findsNothing);

      await tester.tap(find.text('Danger zone'));
      await tester.pumpAndSettle();
      expect(find.text('Reset data'), findsOneWidget);
    });

    testWidgets('keeps reset behind an explicit acknowledgement', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Danger zone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset data'));
      await tester.pumpAndSettle();

      final confirm = find.widgetWithText(TextButton, 'Reset and restart');
      expect(confirm, findsOneWidget);
      expect(tester.widget<TextButton>(confirm).onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(confirm).onPressed, isNotNull);
    });

    testWidgets('persists the report so the failure survives a restart', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settleDiagnostics(tester);

      final logs = Directory('${directory.path}/logs');
      final reports = logs
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('startup_failure_'))
          .toList();
      expect(reports, hasLength(1));
      expect(
        reports.single.readAsStringSync(),
        contains('database_identity_mismatch'),
      );
    });
  });
}
