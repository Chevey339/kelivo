import 'dart:io';

import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/pages/skills_page.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_detail.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_import.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import 'skills_test_fakes.dart';

class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeSkillsService skills;
  FilePicker? previousFilePicker;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_skills_pane_');
    try {
      previousFilePicker = FilePicker.platform;
    } catch (_) {
      previousFilePicker = null;
    }
    FilePicker.platform = _FakeFilePicker();
  });

  tearDown(() async {
    if (previousFilePicker != null) {
      FilePicker.platform = previousFilePicker!;
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> settleOverlay(WidgetTester tester) async {
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  Future<void> dismissImportUi(WidgetTester tester) async {
    await settleOverlay(tester);
    final sheet = find.byType(FormSheet);
    if (sheet.evaluate().isEmpty) return;
    Navigator.of(tester.element(sheet.last)).pop();
    await settleOverlay(tester);
  }

  Future<AppLocalizations> pumpPane(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<SkillsService>.value(value: skills),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: SkillsPane(showHeader: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return AppLocalizations.of(tester.element(find.byType(SkillsPane)))!;
  }

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<SkillsService>.value(value: skills),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SkillsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('renders list, useCount, and calls setEnabled', (tester) async {
    final skill = createTempSkill(
      id: 'pdf-tools',
      name: 'PDF Tools',
      description: 'Extract text from PDFs',
      useCount: 3,
      source: SkillSource.file,
      parent: tempDir,
    );
    skills = FakeSkillsService(skills: [skill], skillsDirectory: tempDir);

    final l10n = await pumpPane(tester);

    expect(find.byKey(SkillsPane.listKey), findsOneWidget);
    expect(find.byKey(SkillsPane.itemKey('pdf-tools')), findsOneWidget);
    expect(find.text('PDF Tools'), findsOneWidget);
    expect(find.text('Extract text from PDFs'), findsOneWidget);
    expect(find.text(l10n.skillsUsedCount(3)), findsOneWidget);
    expect(find.text('File'), findsNothing);
    expect(find.text('Pasted'), findsNothing);

    await tester.tap(find.byKey(SkillsPane.enableKey('pdf-tools')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(skills.enabledCalls, [('pdf-tools', false)]);
    expect(skills.skills.single.record.enabled, isFalse);
  });

  testWidgets('import paste calls importFromText and shows validation error', (
    tester,
  ) async {
    skills = FakeSkillsService(skills: const [], skillsDirectory: tempDir);

    await pumpPane(tester);
    expect(find.byKey(SkillsPane.emptyKey), findsOneWidget);

    await tester.tap(find.byKey(SkillsPane.importPasteKey));
    await settleOverlay(tester);

    await tester.enterText(find.byType(TextField), 'not a skill');
    final l10n = AppLocalizations.of(tester.element(find.byType(FormSheet)))!;
    final submit = find.text(l10n.skillsImportConfirm);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(skills.importedTexts, ['not a skill']);
    expect(find.byKey(SkillsPane.importErrorKey), findsOneWidget);
    expect(find.textContaining('Invalid SKILL.md'), findsOneWidget);
    expect(skills.skills, isEmpty);
  });

  testWidgets('paste, file, and GitHub import flows open without exceptions', (
    tester,
  ) async {
    skills = FakeSkillsService(skills: const [], skillsDirectory: tempDir);
    await pumpPane(tester);
    expect(find.byKey(SkillsPane.emptyKey), findsOneWidget);
    expect(find.byKey(SkillsPane.importPasteKey), findsOneWidget);
    expect(find.byKey(SkillsPane.importFileKey), findsOneWidget);
    expect(find.byKey(SkillsPane.importGitHubKey), findsOneWidget);

    Future<void> openFlow(Finder trigger) async {
      await tester.tap(trigger);
      await settleOverlay(tester);
      expect(tester.takeException(), isNull);
      await dismissImportUi(tester);
      expect(tester.takeException(), isNull);
    }

    await openFlow(find.byKey(SkillsPane.importPasteKey));
    await openFlow(find.byKey(SkillsPane.importFileKey));
    await openFlow(find.byKey(SkillsPane.importGitHubKey));

    final l10n = AppLocalizations.of(tester.element(find.byType(SkillsPane)))!;
    await tester.tap(find.byKey(SkillsPane.importKey));
    await settleOverlay(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l10n.skillsImportGitHub).last);
    await settleOverlay(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(FormSheet), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('skills page has + in AppBar.actions and no Plus in the body', (
    tester,
  ) async {
    skills = FakeSkillsService(skills: const [], skillsDirectory: tempDir);
    await pumpPage(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Lucide.Plus),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SkillsPane),
        matching: find.byIcon(Lucide.Plus),
      ),
      findsNothing,
    );
    expect(find.byKey(SkillsPane.importPasteKey), findsOneWidget);
    expect(find.byKey(SkillsPane.importFileKey), findsOneWidget);
    expect(find.byKey(SkillsPane.importGitHubKey), findsOneWidget);
  });

  testWidgets('detail renders MarkdownWithCodeHighlight', (tester) async {
    final skill = createTempSkill(
      id: 'md-skill',
      name: 'Markdown Skill',
      description: 'Has a body',
      parent: tempDir,
    );
    skills = FakeSkillsService(skills: [skill], skillsDirectory: tempDir);

    await pumpPane(tester);

    await tester.tap(find.byKey(SkillsPane.itemKey('md-skill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MarkdownWithCodeHighlight), findsOneWidget);
    final markdown = tester.widget<MarkdownWithCodeHighlight>(
      find.byType(MarkdownWithCodeHighlight),
    );
    expect(markdown.text, contains('# Markdown Skill'));
    expect(markdown.text, isNot(contains('name:')));
    expect(markdown.text, isNot(contains('description:')));
    expect(find.textContaining('name:'), findsNothing);
    expect(find.textContaining('description:'), findsNothing);
  });

  testWidgets('detail body omits YAML frontmatter and keeps the heading', (
    tester,
  ) async {
    final skill = createTempSkill(
      id: 'frontmatter-skill',
      name: 'Demo Heading',
      description: 'A demo skill for verification',
      parent: tempDir,
    );
    skills = FakeSkillsService(skills: [skill], skillsDirectory: tempDir);

    await pumpPane(tester);
    await tester.tap(find.byKey(SkillsPane.itemKey('frontmatter-skill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('name:'), findsNothing);
    expect(find.textContaining('description:'), findsNothing);
    expect(find.byType(MarkdownWithCodeHighlight), findsOneWidget);
    expect(
      tester
          .widget<MarkdownWithCodeHighlight>(
            find.byType(MarkdownWithCodeHighlight),
          )
          .text,
      contains('# Demo Heading'),
    );
  });

  testWidgets('empty skill body shows the empty-state recipe', (tester) async {
    final skill = createTempSkill(
      id: 'empty-body',
      name: 'Empty Body',
      description: 'No instructions',
      parent: tempDir,
    );
    File(skill.skillMdPath).writeAsStringSync('''
---
name: Empty Body
description: No instructions
---
''');
    skills = FakeSkillsService(skills: [skill], skillsDirectory: tempDir);

    await pumpPane(tester);
    await tester.tap(find.byKey(SkillsPane.itemKey('empty-body')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MarkdownWithCodeHighlight), findsNothing);
    expect(find.byKey(SkillsKeys.bodyEmpty), findsOneWidget);
    expect(find.textContaining('name:'), findsNothing);
  });

  testWidgets('detail AppBar has switch and more; menu is destructive delete', (
    tester,
  ) async {
    final skill = createTempSkill(
      id: 'grid-skill',
      name: 'Grid Skill',
      description: 'Actions',
      parent: tempDir,
    );
    skills = FakeSkillsService(skills: [skill], skillsDirectory: tempDir);

    await pumpPane(tester);
    await tester.tap(find.byKey(SkillsPane.itemKey('grid-skill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SkillDetailView)),
    )!;
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IosSwitch),
      ),
      findsOneWidget,
    );
    expect(find.byKey(SkillsKeys.more), findsOneWidget);
    expect(find.byIcon(Lucide.Ellipsis), findsOneWidget);
    expect(find.byKey(SkillsKeys.actions), findsNothing);
    expect(find.text(l10n.skillsDetailKindLabel), findsOneWidget);

    await tester.tap(find.byKey(SkillsKeys.more));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text(l10n.skillsBrowseFiles), findsOneWidget);
    expect(find.text(l10n.skillsEdit), findsOneWidget);
    expect(find.text(l10n.skillsExport), findsOneWidget);
    expect(find.text(l10n.skillsDelete), findsOneWidget);
    final error = Theme.of(
      tester.element(find.text(l10n.skillsDelete)),
    ).colorScheme.error;
    expect(tester.widget<Icon>(find.byIcon(Lucide.Trash2)).color, error);
    expect(
      tester.widget<Text>(find.text(l10n.skillsDelete)).style?.color,
      error,
    );
  });

  testWidgets('desktop detail header has switch and more, no footer actions', (
    tester,
  ) async {
    final skill = createTempSkill(
      id: 'desk-skill',
      name: 'Desk Skill',
      description: 'Footer',
      parent: tempDir,
    );
    skills = FakeSkillsService(skills: [skill], skillsDirectory: tempDir);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<SkillsService>.value(value: skills),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SizedBox(
              width: 720,
              height: 640,
              child: SkillDetailView(skillId: 'desk-skill', dialog: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(IosSwitch), findsOneWidget);
    expect(find.byKey(SkillsKeys.more), findsOneWidget);
    expect(find.byKey(SkillsKeys.actions), findsNothing);
    expect(find.byKey(SkillsKeys.browse), findsNothing);
    expect(find.byKey(SkillsKeys.delete), findsNothing);
  });

  testWidgets('GitHub import sheet height tracks content and viewInsets', (
    tester,
  ) async {
    skills = FakeSkillsService(skills: const [], skillsDirectory: tempDir);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    Future<void> pumpHost() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<SkillsService>.value(value: skills),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () {
                      showSkillGitHubImport(context);
                    },
                    child: const Text('open-github'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open-github'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    await pumpHost();
    expect(find.byType(FormSheet), findsOneWidget);
    final closed = tester.getSize(find.byType(FormSheet)).height;
    expect(closed, lessThan(800 * 0.9));
    expect(closed, lessThan(400));
    expect(closed, greaterThan(120));

    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pump();
    await tester.pumpAndSettle();
    final open = tester.getSize(find.byType(FormSheet)).height;
    expect(open - closed, closeTo(240, 2));
    const insetTop = 800.0 - 240.0;
    final field = tester.getRect(find.byType(TextField));
    final actions = tester.getRect(find.byType(FormSheetActions));
    expect(field.bottom, lessThanOrEqualTo(insetTop + 0.5));
    expect(actions.bottom, lessThanOrEqualTo(insetTop + 0.5));
    expect(actions.top, greaterThan(field.bottom));
  });

  testWidgets('empty-state CTAs share the same width', (tester) async {
    skills = FakeSkillsService(skills: const [], skillsDirectory: tempDir);
    await pumpPane(tester);

    final paste = tester.getSize(find.byKey(SkillsPane.importPasteKey));
    final file = tester.getSize(find.byKey(SkillsPane.importFileKey));
    final github = tester.getSize(find.byKey(SkillsPane.importGitHubKey));
    expect(paste.width, file.width);
    expect(file.width, github.width);
    expect(find.byType(GitHubGlyph), findsOneWidget);
  });

  test('skillDetailMarkdownBody drops frontmatter', () {
    const raw = '''
---
name: demo-skill
description: A demo skill for verification
---
# Demo

Say hello.
''';
    final body = skillDetailMarkdownBody(raw);
    expect(body, contains('# Demo'));
    expect(body, contains('Say hello.'));
    expect(body, isNot(contains('name:')));
    expect(body, isNot(contains('description:')));
  });

  testWidgets('delete confirms then calls delete', (tester) async {
    final skill = createTempSkill(
      id: 'old-skill',
      name: 'Old Skill',
      description: 'Remove me',
      parent: tempDir,
    );
    skills = FakeSkillsService(skills: [skill], skillsDirectory: tempDir);

    await pumpPane(tester);

    await tester.tap(find.byKey(SkillsPane.itemKey('old-skill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(SkillsKeys.more));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SkillDetailView)),
    )!;
    await tester.tap(find.text(l10n.skillsDelete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-confirm-accept')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(skills.deletedIds, ['old-skill']);
    expect(skills.skills, isEmpty);
  });
}
