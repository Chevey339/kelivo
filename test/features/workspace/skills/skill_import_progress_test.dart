import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_import.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/animated_progress_bar.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import 'skills_test_fakes.dart';

class _ProgressSkillsService extends FakeSkillsService {
  Completer<Skill>? pending;
  ValueChanged<SkillImportProgress>? report;
  Future<void>? cancelled;
  int attempts = 0;

  @override
  Future<Skill> importFromGitHub(
    String url, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) {
    attempts++;
    pending = Completer<Skill>();
    report = onProgress;
    cancelled = cancelSignal;
    report!(const SkillImportProgress(SkillImportPhase.resolving));
    return pending!.future;
  }
}

void main() {
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      'GitHub progress, retry and dismissal on $platform',
      (tester) async {
        tester.view.physicalSize = platform == TargetPlatform.macOS
            ? const Size(1100, 800)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final skills = _ProgressSkillsService();
        addTearDown(skills.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider<SkillsService>.value(value: skills),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showSkillGitHubImport(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          find.byType(BottomSheet),
          platform == TargetPlatform.macOS ? findsNothing : findsOneWidget,
        );
        await tester.enterText(
          find.byType(TextField),
          'https://github.com/acme/demo',
        );
        tester
            .widget<FormSheetActions>(find.byType(FormSheetActions))
            .onConfirm!();
        await tester.pump();
        expect(find.text('Resolving repository…'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(
          tester
              .widget<FormSheetActions>(find.byType(FormSheetActions))
              .onConfirm,
          isNull,
        );
        skills.report!(
          const SkillImportProgress(
            SkillImportPhase.downloading,
            receivedBytes: 25 * 1024 * 1024,
          ),
        );
        await tester.pump();
        expect(find.text('25.00 MB'), findsOneWidget);
        expect(
          find.byKey(AnimatedProgressBar.indeterminateKey),
          findsOneWidget,
        );
        skills.report!(
          const SkillImportProgress(
            SkillImportPhase.downloading,
            receivedBytes: 25 * 1024 * 1024,
            totalBytes: 100 * 1024 * 1024,
          ),
        );
        await tester.pump();
        expect(find.text('25%'), findsOneWidget);
        expect(find.text('25.00 MB / 100.00 MB'), findsOneWidget);
        expect(
          tester
              .widget<AnimatedProgressBar>(find.byType(AnimatedProgressBar))
              .fraction,
          0.25,
        );
        skills.report!(const SkillImportProgress(SkillImportPhase.extracting));
        await tester.pump();
        expect(find.text('Extracting…'), findsOneWidget);
        skills.report!(const SkillImportProgress(SkillImportPhase.installing));
        await tester.pump();
        expect(find.text('Installing…'), findsOneWidget);
        skills.pending!.completeError(const FormatException('bad archive'));
        await tester.pumpAndSettle();
        expect(find.text('bad archive'), findsOneWidget);
        expect(find.byType(AnimatedProgressBar), findsNothing);
        tester
            .widget<FormSheetActions>(find.byType(FormSheetActions))
            .onConfirm!();
        await tester.pump();
        expect(skills.attempts, 2);
        expect(find.text('bad archive'), findsNothing);
        expect(find.text('Resolving repository…'), findsOneWidget);
        tester
            .widget<FormSheetActions>(find.byType(FormSheetActions))
            .onCancel();
        await tester.pumpAndSettle();
        await skills.cancelled;
        skills.report!(const SkillImportProgress(SkillImportPhase.downloading));
        skills.pending!.completeError(const SocketException('cancelled'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(SkillTextImportForm), findsNothing);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
