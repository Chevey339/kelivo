import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_schedule.dart';
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
Future<void> settleDiagnostics(WidgetTester tester) async {
  final l10n = AppLocalizations.of(
    tester.element(find.byType(RestoreFailureScreen)),
  )!;
  bool loading() =>
      find.text(l10n.startupRecoveryCollecting).evaluate().isNotEmpty ||
      find.text(l10n.startupRecoveryBusy).evaluate().isNotEmpty;
  for (var round = 0; round < 500 && loading(); round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
  expect(
    loading(),
    isFalse,
    reason:
        'Diagnostics and local snapshots must finish loading before assertions.',
  );
}

void main() {
  setUpAll(() async {
    final font =
        Platform.environment['KELIVO_RECOVERY_FONT'] ??
        'dependencies/gpt_markdown/lib/fonts/JetBrainsMono-Regular.ttf';
    final bytes = await File(font).readAsBytes();
    await (FontLoader(
      'RecoveryPreview',
    )..addFont(Future.value(bytes.buffer.asByteData()))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });
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

    Future<void> writeSnapshot(DateTime at, int messages) async {
      final snapshots = Directory('${directory.path}/snapshots');
      await snapshots.create();
      final archive = File(
        '${snapshots.path}/${LocalSnapshotPaths.fileNameFor(at)}',
      );
      await archive.writeAsString('snapshot archive');
      await File(
        '${archive.path}${LocalSnapshotPaths.metadataSuffix}',
      ).writeAsString(
        jsonEncode({'conversationCount': 2, 'messageCount': messages}),
      );
    }

    for (final brightness in Brightness.values) {
      testWidgets('snapshot picker fits a narrow phone in ${brightness.name}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.runAsync(
          () => writeSnapshot(DateTime.utc(2026, 9, 10, 12), 42),
        );
        final palette = ThemePalettes.defaultPalette;
        final theme = brightness == Brightness.light
            ? buildLightThemeForScheme(palette.light)
            : buildDarkThemeForScheme(palette.dark);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'RecoveryPreview'),
              ),
              home: RestoreFailureScreen(
                report: reportFor(StateError('database_missing')),
                restart: () async {},
                appDataDirectory: directory,
                appVersionLoader: stubVersion,
              ),
            ),
          ),
        );
        await settleDiagnostics(tester);
        final button = find.text('Choose a snapshot');
        expect(tester.getRect(button).bottom, lessThan(844));
        expect(tester.takeException(), isNull);
        Future<void> capture(String stage) async {
          final destination =
              Platform.environment['KELIVO_RECOVERY_SCREENSHOTS'];
          if (destination == null) return;
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(destination).create(recursive: true);
              await File(
                '$destination/recovery-${brightness.name}-$stage.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }

        await capture('page');
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('2 chats · 42 messages'), findsOneWidget);
        expect(
          tester.getRect(find.byType(AlertDialog)).right,
          lessThanOrEqualTo(390),
        );
        expect(tester.takeException(), isNull);
        await capture('picker');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });
    }

    testWidgets(
      'offers snapshots before diagnostics and confirms before restore',
      (tester) async {
        await tester.runAsync(
          () => writeSnapshot(DateTime(2026, 9, 10, 12).toUtc(), 42),
        );
        await pumpScreen(tester);
        await settleDiagnostics(tester);
        expect(find.text('Choose a snapshot'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Choose a snapshot')).dy,
          lessThan(tester.getTopLeft(find.text('What failed')).dy),
        );
        await tester.tap(find.text('Choose a snapshot'));
        await tester.pumpAndSettle();
        expect(find.text('2 chats · 42 messages'), findsOneWidget);
        await tester.tap(find.text('2 chats · 42 messages'));
        await tester.pumpAndSettle();
        expect(find.text('Restore this copy?'), findsOneWidget);
        expect(find.textContaining('2026-09-10 12:00'), findsOneWidget);
        expect(
          find.textContaining('Changes made after this snapshot'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Restore this copy?'), findsNothing);
        expect(
          Directory('${directory.path}/.kelivo_restore').existsSync(),
          isFalse,
        );
        expect(
          Directory('${directory.path}/snapshots').listSync(),
          hasLength(2),
        );
      },
    );

    testWidgets(
      'failed snapshot validation stays on recovery and allows retry',
      (tester) async {
        await tester.runAsync(
          () => writeSnapshot(DateTime.utc(2026, 9, 10), 42),
        );
        useTallSurface(tester);
        var restarts = 0;
        await tester.pumpWidget(
          wrap(
            RestoreFailureScreen(
              report: reportFor(StateError('database_missing')),
              restart: () async {
                restarts++;
              },
              appDataDirectory: directory,
              appVersionLoader: stubVersion,
            ),
          ),
        );
        await settleDiagnostics(tester);
        await tester.tap(find.text('Choose a snapshot'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2 chats · 42 messages'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Restore'));
        await tester.pump();
        expect(find.text('Preparing copy'), findsOneWidget);
        for (var round = 0; round < 100; round++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (find
              .textContaining('Could not prepare the snapshot restore')
              .evaluate()
              .isNotEmpty) {
            break;
          }
        }
        expect(
          find.textContaining('Could not prepare the snapshot restore'),
          findsOneWidget,
        );
        expect(find.text('Choose a snapshot'), findsOneWidget);
        expect(restarts, 0);
        expect(
          Directory('${directory.path}/.kelivo_restore').existsSync(),
          isFalse,
        );
      },
    );

    testWidgets(
      'explains when no snapshot exists without offering an empty picker',
      (tester) async {
        await pumpScreen(tester);
        await settleDiagnostics(tester);
        expect(
          find.textContaining('No database snapshots were found'),
          findsOneWidget,
        );
        expect(find.text('Choose a snapshot'), findsNothing);
      },
    );

    testWidgets('hides snapshot recovery while another process owns the data', (
      tester,
    ) async {
      await tester.runAsync(() => writeSnapshot(DateTime.utc(2026, 9, 10), 42));
      useTallSurface(tester);
      await tester.pumpWidget(
        wrap(
          RestoreFailureScreen(
            report: reportFor(StateError('RestoreBusinessLeaseUnavailable')),
            restart: () async {},
            appDataDirectory: directory,
            appVersionLoader: stubVersion,
          ),
        ),
      );
      await settleDiagnostics(tester);
      expect(find.text('Choose a snapshot'), findsNothing);
      expect(find.text('Restore from a database snapshot'), findsNothing);
    });

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
