import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant_copy_options.dart';
import 'package:Kelivo/core/models/assistant_memory.dart';
import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/services/assistant_copy_service.dart';
import 'package:Kelivo/features/assistant/widgets/assistant_copy_dialog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';

AssistantCopyMemories _memories() => AssistantCopyMemories(
  entries: [
    for (var i = 1; i <= 3; i++)
      MemoryEntry(
        id: 'mem_$i',
        assistantId: 'source',
        scope: MemoryScope.assistant,
        type: i == 3 ? MemoryType.workflow : MemoryType.identity,
        status: i == 2 ? MemoryStatus.archived : MemoryStatus.active,
        content: 'Memory $i',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
  ],
  legacy: const [
    AssistantMemory(id: 7, assistantId: 'source', content: 'Old memory'),
  ],
);

Future<void> _open(
  WidgetTester tester, {
  required Future<String> Function(AssistantCopyOptions) onCopy,
  Future<AssistantCopyMemories> Function()? loadMemories,
  double width = 430,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAssistantCopyDialog(
              context,
              assistantName: 'Role',
              onCopy: onCopy,
              loadMemories: loadMemories ?? () async => _memories(),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _tap(
  WidgetTester tester,
  String id, {
  bool memoryList = false,
}) async {
  final finder = find.byKey(ValueKey('assistant-copy-$id'));
  if (memoryList) {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey('assistant-copy-memories')),
        matching: find.byType(Scrollable),
      ),
    );
  } else {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.descendant(
          of: find.byKey(const PageStorageKey('assistant-copy-ranges')),
          matching: find.byType(Scrollable),
        ),
      );
    }
    await tester.ensureVisible(finder);
  }
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('inline memory navigation keeps the copy scope unchanged', (
      tester,
    ) async {
      AssistantCopyOptions? chosen;
      await _open(
        tester,
        width: platform == TargetPlatform.iOS ? 320 : 1200,
        onCopy: (options) async {
          chosen = options;
          return 'copy';
        },
      );
      await _tap(tester, 'choose-memories');
      await _tap(tester, 'memory-back');
      expect(
        tester
            .widget<IosCheckbox>(
              find.byKey(const ValueKey('assistant-copy-memories')),
            )
            .value,
        isFalse,
      );
      await _tap(tester, 'memories');
      await _tap(tester, 'choose-memories');
      await _tap(tester, 'memory-back');
      expect(
        tester
            .widget<IosCheckbox>(
              find.byKey(const ValueKey('assistant-copy-memories')),
            )
            .value,
        isTrue,
      );
      await _tap(tester, 'confirm');
      expect(chosen!.memories, isTrue);
      expect(chosen!.memoryIds, isNull);
      expect(chosen!.legacyMemoryIds, isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

  for (final action in ['confirm', 'close', 'all']) {
    testWidgets('$action does not load the memory picker dataset', (
      tester,
    ) async {
      var loads = 0;
      await _open(
        tester,
        loadMemories: () async {
          loads++;
          return _memories();
        },
        onCopy: (_) async => 'copy',
      );
      expect(loads, 0);
      await _tap(tester, action);
      expect(loads, 0);
    });
  }

  for (final empty in [false, true]) {
    testWidgets('successful memory load is cached on reentry, empty=$empty', (
      tester,
    ) async {
      var loads = 0;
      await _open(
        tester,
        loadMemories: () async {
          loads++;
          return empty
              ? const AssistantCopyMemories(entries: [], legacy: [])
              : _memories();
        },
        onCopy: (_) async => 'copy',
      );
      expect(loads, 0);
      await _tap(tester, 'choose-memories');
      expect(loads, 1);
      await _tap(tester, 'memory-back');
      await _tap(tester, 'choose-memories');
      expect(loads, 1);
    });
  }

  testWidgets('reentering the memory picker shares its in-flight load', (
    tester,
  ) async {
    var loads = 0;
    final pending = Completer<AssistantCopyMemories>();
    await _open(
      tester,
      loadMemories: () {
        loads++;
        return pending.future;
      },
      onCopy: (_) async => 'copy',
    );
    expect(loads, 0);
    await tester.tap(
      find.byKey(const ValueKey('assistant-copy-choose-memories')),
    );
    await tester.pump();
    expect(loads, 1);
    await _tap(tester, 'memory-back');
    await tester.tap(
      find.byKey(const ValueKey('assistant-copy-choose-memories')),
    );
    await tester.pump();
    expect(loads, 1);
    pending.complete(_memories());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('assistant-copy-group-identity')),
      findsOneWidget,
    );
    await _tap(tester, 'memory-back');
    await _tap(tester, 'choose-memories');
    expect(loads, 1);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets(
      '$platform uses the shared chooser and preserves the default copy scope',
      (tester) async {
        AssistantCopyOptions? chosen;
        await _open(
          tester,
          onCopy: (options) async {
            chosen = options;
            return 'copy';
          },
        );
        final mobile =
            platform == TargetPlatform.android ||
            platform == TargetPlatform.iOS;
        expect(
          find.byType(BottomSheet),
          mobile ? findsOneWidget : findsNothing,
        );
        expect(find.byType(Dialog), mobile ? findsNothing : findsOneWidget);
        final configuration = tester.widget<IosCheckbox>(
          find.byKey(const ValueKey('assistant-copy-config')),
        );
        expect(configuration.value, isTrue);
        expect(configuration.onChanged, isNull);
        await _tap(tester, 'confirm');
        expect(chosen, isNotNull);
        expect(chosen!.memories, isFalse);
        expect(chosen!.quickPhrases, isFalse);
        expect(chosen!.worldBooks, isFalse);
        expect(chosen!.instructionInjections, isFalse);
        expect(
          chosen!.regexRules &&
              chosen!.skills &&
              chosen!.mcp &&
              chosen!.tools &&
              chosen!.workspace,
          isTrue,
        );
        expect(find.text('Copy assistant'), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets(
    'memory categories and individual entries produce a precise selection',
    (tester) async {
      AssistantCopyOptions? chosen;
      await _open(
        tester,
        onCopy: (options) async {
          chosen = options;
          return 'copy';
        },
      );
      await _tap(tester, 'choose-memories');
      await _tap(tester, 'group-identity', memoryList: true);
      await _tap(tester, 'expand-identity', memoryList: true);
      await _tap(tester, 'memory-mem_1', memoryList: true);
      await _tap(tester, 'group-legacy', memoryList: true);
      await _tap(tester, 'memory-back');
      await _tap(tester, 'confirm');
      expect(chosen!.memories, isTrue);
      expect(chosen!.memoryIds, {'mem_2'});
      expect(chosen!.legacyMemoryIds, {7});
    },
  );

  testWidgets(
    'full copy ignores a partial selection and includes every category',
    (tester) async {
      AssistantCopyOptions? chosen;
      await _open(
        tester,
        onCopy: (options) async {
          chosen = options;
          return 'copy';
        },
      );
      await _tap(tester, 'regex');
      await _tap(tester, 'choose-memories');
      await _tap(tester, 'expand-identity', memoryList: true);
      await _tap(tester, 'memory-mem_1', memoryList: true);
      await _tap(tester, 'memory-back');
      await _tap(tester, 'all');
      expect(
        chosen!.memories &&
            chosen!.quickPhrases &&
            chosen!.worldBooks &&
            chosen!.instructionInjections,
        isTrue,
      );
      expect(
        chosen!.regexRules &&
            chosen!.skills &&
            chosen!.mcp &&
            chosen!.tools &&
            chosen!.workspace,
        isTrue,
      );
      expect(chosen!.memoryIds, isNull);
      expect(chosen!.legacyMemoryIds, isNull);
    },
  );

  testWidgets('select all resets earlier memory filters', (tester) async {
    AssistantCopyOptions? chosen;
    await _open(
      tester,
      onCopy: (options) async {
        chosen = options;
        return 'copy';
      },
    );
    await _tap(tester, 'choose-memories');
    await _tap(tester, 'expand-identity', memoryList: true);
    await _tap(tester, 'memory-mem_1', memoryList: true);
    await _tap(tester, 'memories-all', memoryList: true);
    await _tap(tester, 'memory-back');
    await _tap(tester, 'confirm');
    expect(chosen!.memories, isTrue);
    expect(chosen!.memoryIds, isNull);
    expect(chosen!.legacyMemoryIds, isNull);
  });

  testWidgets(
    'copy stays open on failure and prevents duplicate submission while busy',
    (tester) async {
      var calls = 0;
      final pending = Completer<String>();
      await _open(
        tester,
        onCopy: (_) {
          calls++;
          return calls == 1 ? pending.future : Future.value('copy');
        },
      );
      await _tap(tester, 'confirm');
      await _tap(tester, 'all');
      await _tap(tester, 'close');
      await _tap(tester, 'choose-memories');
      expect(find.text('Copy assistant'), findsOneWidget);
      expect(calls, 1);
      expect(find.text('Copying…'), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      expect(find.text('Copy assistant'), findsOneWidget);
      pending.completeError(StateError('write failed'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not copy the assistant. Your original data is unchanged. Please try again.',
        ),
        findsOneWidget,
      );
      await _tap(tester, 'confirm');
      expect(calls, 2);
      expect(find.text('Copy assistant'), findsNothing);
    },
  );

  testWidgets(
    'memory loading failure can be retried without resetting the dialog',
    (tester) async {
      var loads = 0;
      await _open(
        tester,
        loadMemories: () async {
          if (++loads == 1) throw StateError('load');
          return _memories();
        },
        onCopy: (_) async => 'copy',
      );
      expect(loads, 0);
      await _tap(tester, 'choose-memories');
      expect(loads, 1);
      expect(
        find.text('Could not load memories. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await _tap(tester, 'expand-identity', memoryList: true);
      expect(find.text('Memory 1'), findsOneWidget);
      expect(loads, 2);
      await _tap(tester, 'memory-back');
      await _tap(tester, 'choose-memories');
      expect(loads, 2);
    },
  );

  testWidgets('cancel creates no assistant', (tester) async {
    var calls = 0;
    await _open(
      tester,
      onCopy: (_) async {
        calls++;
        return 'copy';
      },
    );
    await _tap(tester, 'close');
    expect(calls, 0);
    expect(find.text('Copy assistant'), findsNothing);
  });

  testWidgets('every optional scope can be changed independently', (
    tester,
  ) async {
    AssistantCopyOptions? chosen;
    await _open(
      tester,
      onCopy: (options) async {
        chosen = options;
        return 'copy';
      },
    );
    for (final id in [
      'memories',
      'phrases',
      'regex',
      'world-books',
      'injections',
      'skills',
      'mcp',
      'tools',
      'workspace',
    ]) {
      await _tap(tester, id);
    }
    await _tap(tester, 'confirm');
    expect(
      chosen!.memories &&
          chosen!.quickPhrases &&
          chosen!.worldBooks &&
          chosen!.instructionInjections,
      isTrue,
    );
    expect(
      chosen!.regexRules ||
          chosen!.skills ||
          chosen!.mcp ||
          chosen!.tools ||
          chosen!.workspace,
      isFalse,
    );
  });
}
