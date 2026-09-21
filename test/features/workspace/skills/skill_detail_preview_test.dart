import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_detail.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/utils/format_bytes.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import 'skills_test_fakes.dart';

const _limit = 100 * 1024;
const _source =
    '---\nname: Preview Skill\ndescription: Instructions\n---\n'
    '# Preview body\n\nKeep **formatting**.';

class _SkillFileStat extends Fake implements FileStat {
  _SkillFileStat(this.size, this.modified, this.type);

  @override
  final int size;
  @override
  final DateTime modified;
  @override
  DateTime get changed => modified;
  @override
  final FileSystemEntityType type;
}

class _SkillFile extends Fake implements File {
  _SkillFile(this.path, String source) : bytes = utf8.encode(source);

  @override
  final String path;
  List<int> bytes;
  int revision = 0;
  bool missing = false;
  int? reportedSize;
  int reads = 0;
  int bytesRead = 0;
  Future<void>? readGate;

  void replace(String source) {
    bytes = utf8.encode(source);
    revision++;
  }

  @override
  Future<FileStat> stat() async => _SkillFileStat(
    reportedSize ?? bytes.length,
    DateTime.utc(2026, 1, 1).add(Duration(seconds: revision)),
    missing ? FileSystemEntityType.notFound : FileSystemEntityType.file,
  );

  @override
  Future<int> length() async => bytes.length;

  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    reads++;
    final data = bytes.sublist(
      start ?? 0,
      math.min(end ?? bytes.length, bytes.length),
    );
    final gate = readGate;
    if (gate != null) await gate;
    bytesRead += data.length;
    yield data;
  }
}

final class _SkillFileOverrides extends IOOverrides {
  _SkillFileOverrides(this.files);
  final List<_SkillFile> files;

  @override
  File createFile(String path) {
    for (final file in files) {
      if (file.path == path) return file;
    }
    return super.createFile(path);
  }
}

void main() {
  late Directory directory;
  late Skill skill;
  late _SkillFile file;
  late FakeSkillsService service;
  late SettingsProvider settings;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('skill_preview_test_');
    skill = createTempSkill(
      id: 'preview-skill',
      name: 'Preview Skill',
      description: 'Instructions',
      parent: directory,
    );
    file = _SkillFile(skill.skillMdPath, _source);
    service = FakeSkillsService(skills: [skill]);
    settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
  });

  tearDown(() {
    settings.dispose();
    service.dispose();
    directory.deleteSync(recursive: true);
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    bool desktop = false,
    Brightness brightness = Brightness.light,
    String? skillId,
  }) async {
    tester.view.physicalSize = desktop
        ? const Size(1280, 800)
        : const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final detail = SkillDetailView(
      skillId: skillId ?? skill.record.id,
      dialog: desktop,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<SkillsService>.value(value: service),
        ],
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? buildDarkThemeForScheme(ThemePalettes.defaultPalette.dark)
              : buildLightThemeForScheme(ThemePalettes.defaultPalette.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: desktop
              ? Scaffold(
                  body: Center(
                    child: SizedBox(width: 720, height: 640, child: detail),
                  ),
                )
              : detail,
        ),
      ),
    );
    await tester.pump();
  }

  AppLocalizations localizations(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(SkillDetailView)))!;

  for (final size in [_limit - 1, _limit, _limit + 1]) {
    testWidgets('preview limit uses file bytes: $size', (tester) async {
      file.replace(_source.padRight(size));
      await IOOverrides.runWithIOOverrides(() async {
        await pumpDetail(tester);
        await tester.pumpAndSettle();
        if (size <= _limit) {
          expect(find.byType(MarkdownWithCodeHighlight), findsOneWidget);
          expect(
            tester
                .widget<MarkdownWithCodeHighlight>(
                  find.byType(MarkdownWithCodeHighlight),
                )
                .text,
            '# Preview body\n\nKeep **formatting**.',
          );
          expect(file.reads, 1);
          expect(file.bytesRead, size);
        } else {
          expect(find.byKey(SkillsKeys.bodyTooLarge), findsOneWidget);
          expect(find.byType(MarkdownWithCodeHighlight), findsNothing);
          expect(file.reads, 0);
          expect(file.bytesRead, 0);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, _SkillFileOverrides([file]));
    });
  }

  for (final desktop in [false, true]) {
    for (final brightness in Brightness.values) {
      testWidgets('oversized file hint: desktop=$desktop, $brightness', (
        tester,
      ) async {
        file.replace('界' * 40000);
        expect(utf8.decode(file.bytes).length, lessThan(_limit));
        await IOOverrides.runWithIOOverrides(() async {
          await pumpDetail(tester, desktop: desktop, brightness: brightness);
          await tester.pumpAndSettle();
          final l10n = localizations(tester);
          final hint = find.text(
            l10n.skillsDetailBodyTooLarge(formatBytes(file.bytes.length)),
          );
          expect(hint, findsOneWidget);
          expect(find.text('Instructions'), findsOneWidget);
          expect(find.byType(MarkdownWithCodeHighlight), findsNothing);
          expect(file.reads, 0);
          final bounds = tester.getRect(find.byType(ListView));
          final hintBounds = tester.getRect(hint);
          expect(bounds.contains(hintBounds.topLeft), isTrue);
          expect(bounds.contains(hintBounds.bottomRight), isTrue);

          await tester.tap(find.byKey(SkillsKeys.more));
          await tester.pumpAndSettle();
          expect(find.text(l10n.skillsBrowseFiles), findsOneWidget);
          expect(find.text(l10n.skillsEdit), findsOneWidget);
          expect(find.text(l10n.skillsExport), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, _SkillFileOverrides([file]));
      });
    }
  }

  testWidgets('rebuilds and metadata changes reuse the loaded body', (
    tester,
  ) async {
    await IOOverrides.runWithIOOverrides(() async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();
      final markdownState = tester.state(
        find.byType(MarkdownWithCodeHighlight),
      );
      await service.setEnabled(skill.record.id, false);
      await tester.pumpAndSettle();
      await pumpDetail(tester, brightness: Brightness.dark);
      await tester.pumpAndSettle();
      await service.rescan();
      await tester.pumpAndSettle();
      expect(file.reads, 1);
      expect(
        tester.state(find.byType(MarkdownWithCodeHighlight)),
        same(markdownState),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, _SkillFileOverrides([file]));
  });

  testWidgets('editing and rescanning refresh the cached body and size gate', (
    tester,
  ) async {
    await IOOverrides.runWithIOOverrides(() async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();
      file.replace(_source.replaceFirst('Preview body', 'Changed body'));
      await service.updateBody(skill.record.id, utf8.decode(file.bytes));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MarkdownWithCodeHighlight>(
              find.byType(MarkdownWithCodeHighlight),
            )
            .text,
        startsWith('# Changed body'),
      );
      expect(file.reads, 2);

      file.replace('x' * (_limit + 1));
      await service.rescan();
      await tester.pumpAndSettle();
      expect(find.byKey(SkillsKeys.bodyTooLarge), findsOneWidget);
      expect(find.byType(MarkdownWithCodeHighlight), findsNothing);
      expect(file.reads, 2);

      file.replace('# Small again');
      await service.rescan();
      await tester.pumpAndSettle();
      expect(find.byKey(SkillsKeys.bodyTooLarge), findsNothing);
      expect(
        tester
            .widget<MarkdownWithCodeHighlight>(
              find.byType(MarkdownWithCodeHighlight),
            )
            .text,
        '# Small again',
      );
      expect(file.reads, 3);
      await tester.pumpWidget(const SizedBox.shrink());
    }, _SkillFileOverrides([file]));
  });

  testWidgets('read stays bounded if the file grows after stat', (
    tester,
  ) async {
    file.replace('x' * (_limit * 4));
    file.reportedSize = 50;
    await IOOverrides.runWithIOOverrides(() async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();
      expect(file.bytesRead, _limit + 1);
      expect(
        find.text(localizations(tester).skillsDetailBodyTooLarge('400.0 KB')),
        findsOneWidget,
      );
      expect(find.byType(MarkdownWithCodeHighlight), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, _SkillFileOverrides([file]));
  });

  testWidgets('empty, missing and malformed files keep their existing states', (
    tester,
  ) async {
    file.replace('---\nname: Empty\ndescription: No instructions\n---\n');
    await IOOverrides.runWithIOOverrides(() async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(SkillsKeys.bodyEmpty), findsOneWidget);
      file.missing = true;
      await service.rescan();
      await tester.pumpAndSettle();
      expect(
        find.text(localizations(tester).workspaceFileNotAvailable),
        findsOneWidget,
      );
      file.missing = false;
      file.bytes = [0xff, 0xfe];
      file.revision++;
      await service.rescan();
      await tester.pumpAndSettle();
      expect(
        find.text(localizations(tester).workspaceFileNotAvailable),
        findsOneWidget,
      );
      expect(find.byType(MarkdownWithCodeHighlight), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, _SkillFileOverrides([file]));
  });

  testWidgets('an older read cannot replace a freshly edited body', (
    tester,
  ) async {
    final gate = Completer<void>();
    file.readGate = gate.future;
    await IOOverrides.runWithIOOverrides(() async {
      await pumpDetail(tester);
      expect(find.byKey(SkillsKeys.bodyLoading), findsOneWidget);
      file.replace('# Updated while loading');
      file.readGate = null;
      await service.updateBody(skill.record.id, utf8.decode(file.bytes));
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MarkdownWithCodeHighlight>(
              find.byType(MarkdownWithCodeHighlight),
            )
            .text,
        '# Updated while loading',
      );
      expect(file.reads, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, _SkillFileOverrides([file]));
  });

  testWidgets('a disposed preview ignores an unfinished read', (tester) async {
    final gate = Completer<void>();
    file.readGate = gate.future;
    await IOOverrides.runWithIOOverrides(() async {
      await pumpDetail(tester);
      expect(find.byKey(SkillsKeys.bodyLoading), findsOneWidget);
      expect(file.reads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }, _SkillFileOverrides([file]));
  });
}
