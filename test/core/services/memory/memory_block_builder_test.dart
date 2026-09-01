import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/models/user_profile_field.dart';
import 'package:Kelivo/core/services/memory/memory_block_builder.dart';
import 'package:Kelivo/core/services/memory/memory_prompts.dart';

MemoryEntry _entry({
  required String id,
  MemoryScope scope = MemoryScope.global,
  String? assistantId,
  MemoryType type = MemoryType.identity,
  required String content,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  return MemoryEntry(
    id: id,
    scope: scope,
    assistantId: assistantId,
    type: type,
    content: content,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

void main() {
  group('MemoryBlockBuilder golden', () {
    test('fixed input produces exact snapshot bytes', () {
      final entries = [
        _entry(
          id: 'mem_voice01',
          type: MemoryType.voice,
          content: '用户偏好直接、详细、可落地的中文说明。',
          createdAt: DateTime(2026, 8, 4, 10),
          updatedAt: DateTime(2026, 8, 4, 10),
        ),
        _entry(
          id: 'mem_id001',
          type: MemoryType.identity,
          content: '用户是大学生，长期参与软件开发项目。',
          createdAt: DateTime(2026, 8, 1, 9),
          updatedAt: DateTime(2026, 8, 7, 12),
        ),
        _entry(
          id: 'mem_wf002',
          type: MemoryType.workflow,
          scope: MemoryScope.assistant,
          assistantId: 'a1',
          content: '回答代码问题时优先给可直接运行的 Dart 示例。',
          createdAt: DateTime(2026, 8, 5, 8),
          updatedAt: DateTime(2026, 8, 5, 8),
        ),
        _entry(
          id: 'mem_wf001',
          type: MemoryType.workflow,
          content: '用户开发 Flutter 应用时重视跨平台与长列表性能。',
          createdAt: DateTime(2026, 8, 3, 8),
          updatedAt: DateTime(2026, 8, 6, 15),
        ),
        _entry(
          id: 'mem_ins01',
          type: MemoryType.instruction,
          content: '不要把已经回答过的问题再问一遍。',
          createdAt: DateTime(2026, 8, 1, 8),
          updatedAt: DateTime(2026, 8, 1, 8),
        ),
      ];
      final fields = [
        UserProfileField(
          key: 'preferred_language',
          value: 'zh-Hans',
          updatedAt: DateTime(2026, 8, 1),
        ),
        UserProfileField(
          key: 'preferred_name',
          value: 'Psyche',
          updatedAt: DateTime(2026, 8, 1),
        ),
        UserProfileField(
          key: 'custom.company',
          value: 'Kelivo',
          updatedAt: DateTime(2026, 8, 2),
        ),
      ];

      final totals = <MemoryType, int>{
        for (final t in MemoryType.values)
          t: entries.where((e) => e.type == t).length,
      };

      final profile = MemoryBlockBuilder.buildProfileBlock(
        fields: fields,
        lang: MemoryPromptLang.zh,
      );
      final memory = MemoryBlockBuilder.buildMemoryBlock(
        visible: entries,
        totalByType: totals,
        lang: MemoryPromptLang.zh,
        maxItems: 10,
      );

      expect(profile, '''
<user_profile>
<preferred_name>Psyche</preferred_name>
<preferred_language>zh-Hans</preferred_language>
<custom name="company">Kelivo</custom>
</user_profile>
''');

      expect(memory, '''
<user_memory type="identity">
- [2026-08-07] 用户是大学生，长期参与软件开发项目。
</user_memory>
<user_memory type="workflow">
- [2026-08-06] 用户开发 Flutter 应用时重视跨平台与长列表性能。
- [2026-08-05] (assistant) 回答代码问题时优先给可直接运行的 Dart 示例。
</user_memory>
<user_memory type="voice">
- [2026-08-04] 用户偏好直接、详细、可落地的中文说明。
</user_memory>
<user_memory type="instruction">
- [2026-08-01] 不要把已经回答过的问题再问一遍。
</user_memory>
''');
    });

    test('shuffling input order does not change output', () {
      final a = _entry(
        id: 'mem_b',
        type: MemoryType.identity,
        content: 'B',
        createdAt: DateTime(2026, 8, 2),
        updatedAt: DateTime(2026, 8, 3),
      );
      final b = _entry(
        id: 'mem_a',
        type: MemoryType.identity,
        content: 'A',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 4),
      );
      final c = _entry(
        id: 'mem_c',
        type: MemoryType.workflow,
        scope: MemoryScope.assistant,
        assistantId: 'x',
        content: 'C',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );

      String build(List<MemoryEntry> list) =>
          MemoryBlockBuilder.buildMemoryBlock(
            visible: list,
            totalByType: {
              MemoryType.identity: 2,
              MemoryType.workflow: 1,
              MemoryType.voice: 0,
              MemoryType.instruction: 0,
            },
            lang: MemoryPromptLang.en,
            maxItems: 10,
          );

      expect(build([a, b, c]), build([c, b, a]));
      expect(build([a, b, c]), build([b, c, a]));
    });
  });

  group('MemoryBlockBuilder boundaries', () {
    test('empty profile emits self-closing tag', () {
      expect(
        MemoryBlockBuilder.buildProfileBlock(
          fields: const [],
          lang: MemoryPromptLang.zh,
        ),
        '<user_profile/>\n',
      );
      expect(
        MemoryBlockBuilder.buildProfileBlock(
          fields: [
            UserProfileField(
              key: 'gender',
              value: '   ',
              updatedAt: DateTime(2026, 1, 1),
            ),
          ],
          lang: MemoryPromptLang.zh,
        ),
        '<user_profile/>\n',
      );
    });

    test('empty types emit self-closing tags', () {
      final out = MemoryBlockBuilder.buildMemoryBlock(
        visible: const [],
        totalByType: const {},
        lang: MemoryPromptLang.zh,
        maxItems: 10,
      );
      expect(out, '''
<user_memory type="identity"/>
<user_memory type="workflow"/>
<user_memory type="voice"/>
<user_memory type="instruction"/>
''');
    });

    test('total == maxItems is full; total == maxItems+1 folds with shown', () {
      MemoryEntry make(int i) => _entry(
        id: 'mem_${i.toString().padLeft(8, '0')}',
        type: MemoryType.identity,
        content: 'entry $i',
        createdAt: DateTime(2026, 1, 1).add(Duration(days: i)),
        updatedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
      );

      const maxItems = 10;
      final atLimit = List.generate(maxItems, make);
      final full = MemoryBlockBuilder.buildMemoryBlock(
        visible: atLimit,
        totalByType: {MemoryType.identity: maxItems},
        lang: MemoryPromptLang.zh,
        maxItems: maxItems,
      );
      expect(full.contains('mode="summary"'), isFalse);
      expect(full.contains('shown='), isFalse);
      expect('\n- ['.allMatches(full).length, maxItems);

      final overLimit = List.generate(maxItems + 1, make);
      final summary = MemoryBlockBuilder.buildMemoryBlock(
        visible: overLimit,
        totalByType: {MemoryType.identity: maxItems + 1},
        lang: MemoryPromptLang.zh,
        maxItems: maxItems,
      );
      expect(
        summary.startsWith(
          '<user_memory type="identity" mode="summary" total="${maxItems + 1}" shown="$maxItems">\n',
        ),
        isTrue,
      );
      expect('\n- ['.allMatches(summary).length, maxItems);
      expect(summary.contains(MemoryPrompts.moreHintZh), isTrue);
      // Newest among 0..10 is index 10; take 10 newest = 1..10, then
      // re-sort by createdAt ASC → still 1..10 chronologically.
      expect(summary.contains('entry 1'), isTrue);
      expect(summary.contains('entry 10'), isTrue);
      expect(summary.contains('entry 0'), isFalse);
    });

    test('maxItems=1 folds extra items to a single shown entry', () {
      MemoryEntry make(int i) => _entry(
        id: 'mem_${i.toString().padLeft(8, '0')}',
        type: MemoryType.identity,
        content: 'entry $i',
        createdAt: DateTime(2026, 1, 1).add(Duration(days: i)),
        updatedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
      );

      final full = MemoryBlockBuilder.buildMemoryBlock(
        visible: [make(0)],
        totalByType: {MemoryType.identity: 1},
        lang: MemoryPromptLang.en,
        maxItems: 1,
      );
      expect(full.contains('mode="summary"'), isFalse);
      expect('\n- ['.allMatches(full).length, 1);

      final summary = MemoryBlockBuilder.buildMemoryBlock(
        visible: [make(0), make(1)],
        totalByType: {MemoryType.identity: 2},
        lang: MemoryPromptLang.en,
        maxItems: 1,
      );
      expect(
        summary,
        contains(
          '<user_memory type="identity" mode="summary" total="2" shown="1">',
        ),
      );
      expect('\n- ['.allMatches(summary).length, 1);
      expect(summary.contains('entry 1'), isTrue);
      expect(summary.contains('entry 0'), isFalse);
      expect(summary.contains(MemoryPrompts.moreHintEn), isTrue);
    });

    test('maxItems=50 keeps 50 full and folds 51', () {
      MemoryEntry make(int i) => _entry(
        id: 'mem_${i.toString().padLeft(8, '0')}',
        type: MemoryType.identity,
        content: 'entry $i',
        createdAt: DateTime(2026, 1, 1).add(Duration(days: i)),
        updatedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
      );

      final fifty = List.generate(50, make);
      final full = MemoryBlockBuilder.buildMemoryBlock(
        visible: fifty,
        totalByType: {MemoryType.identity: 50},
        lang: MemoryPromptLang.zh,
        maxItems: 50,
      );
      expect(full.contains('mode="summary"'), isFalse);
      expect('\n- ['.allMatches(full).length, 50);

      final fiftyOne = List.generate(51, make);
      final summary = MemoryBlockBuilder.buildMemoryBlock(
        visible: fiftyOne,
        totalByType: {MemoryType.identity: 51},
        lang: MemoryPromptLang.zh,
        maxItems: 50,
      );
      expect(
        summary,
        contains(
          '<user_memory type="identity" mode="summary" total="51" shown="50">',
        ),
      );
      expect('\n- ['.allMatches(summary).length, 50);
    });
  });

  group('MemoryBlockBuilder escape/flatten', () {
    test('escapes amp/lt/gt and flattens multiline content', () {
      final entry = _entry(
        id: 'mem_esc001',
        content: 'A & B\n<tag>\r\n  greater > ok',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );
      final out = MemoryBlockBuilder.buildMemoryBlock(
        visible: [entry],
        totalByType: {MemoryType.identity: 1},
        lang: MemoryPromptLang.en,
        maxItems: 10,
      );
      expect(
        out,
        contains('- [2026-08-01] A &amp; B &lt;tag&gt; greater &gt; ok\n'),
      );
    });
  });

  group('MemoryBlockBuilder hash', () {
    test(
      'same data different order → same hash; edit/lang change → different',
      () {
        final e1 = _entry(
          id: 'mem_a',
          content: 'hello',
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        );
        final e2 = _entry(
          id: 'mem_b',
          type: MemoryType.workflow,
          content: 'world',
          createdAt: DateTime(2026, 8, 2),
          updatedAt: DateTime(2026, 8, 2),
        );
        final totals = {
          MemoryType.identity: 1,
          MemoryType.workflow: 1,
          MemoryType.voice: 0,
          MemoryType.instruction: 0,
        };
        final profile = MemoryBlockBuilder.buildProfileBlock(
          fields: const [],
          lang: MemoryPromptLang.zh,
        );
        final m1 = MemoryBlockBuilder.buildMemoryBlock(
          visible: [e1, e2],
          totalByType: totals,
          lang: MemoryPromptLang.zh,
          maxItems: 10,
        );
        final m2 = MemoryBlockBuilder.buildMemoryBlock(
          visible: [e2, e1],
          totalByType: totals,
          lang: MemoryPromptLang.zh,
          maxItems: 10,
        );
        expect(
          MemoryBlockBuilder.hashBlocks(profile, m1),
          MemoryBlockBuilder.hashBlocks(profile, m2),
        );
        expect(MemoryBlockBuilder.hashBlocks(profile, m1).length, 16);

        final edited = MemoryBlockBuilder.buildMemoryBlock(
          visible: [
            _entry(
              id: 'mem_a',
              content: 'hello!',
              createdAt: DateTime(2026, 8, 1),
              updatedAt: DateTime(2026, 8, 1),
            ),
            e2,
          ],
          totalByType: totals,
          lang: MemoryPromptLang.zh,
          maxItems: 10,
        );
        expect(
          MemoryBlockBuilder.hashBlocks(profile, edited),
          isNot(MemoryBlockBuilder.hashBlocks(profile, m1)),
        );

        // Language affects moreHint only in summary mode.
        final many = List.generate(
          31,
          (i) => _entry(
            id: 'mem_${i.toString().padLeft(8, '0')}',
            content: 'e$i',
            createdAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
            updatedAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
          ),
        );
        final zh = MemoryBlockBuilder.buildMemoryBlock(
          visible: many,
          totalByType: {MemoryType.identity: 31},
          lang: MemoryPromptLang.zh,
          maxItems: 10,
        );
        final en = MemoryBlockBuilder.buildMemoryBlock(
          visible: many,
          totalByType: {MemoryType.identity: 31},
          lang: MemoryPromptLang.en,
          maxItems: 10,
        );
        expect(
          MemoryBlockBuilder.hashBlocks(profile, zh),
          isNot(MemoryBlockBuilder.hashBlocks(profile, en)),
        );
      },
    );
  });

  group('MemoryBlockBuilder injection prefixes', () {
    test('full prefix shape matches §7.5', () {
      const profile = '<user_profile/>\n';
      const memory =
          '<user_memory type="identity"/>\n'
          '<user_memory type="workflow"/>\n'
          '<user_memory type="voice"/>\n'
          '<user_memory type="instruction"/>\n';

      expect(
        MemoryBlockBuilder.buildFullSnapshotPrefix(
          profile,
          memory,
          MemoryPromptLang.zh,
        ),
        '${MemoryPrompts.introFullZh}\n$profile$memory\n',
      );
    });
  });

  group('splitInjectedPrefix', () {
    test('splits a full snapshot from the user turn', () {
      final prefix = MemoryBlockBuilder.buildFullSnapshotPrefix(
        MemoryBlockBuilder.buildProfileBlock(
          fields: const [],
          lang: MemoryPromptLang.zh,
        ),
        MemoryBlockBuilder.buildMemoryBlock(
          visible: const [],
          totalByType: const {},
          lang: MemoryPromptLang.zh,
          maxItems: 10,
        ),
        MemoryPromptLang.zh,
      );
      final split = MemoryBlockBuilder.splitInjectedPrefix('$prefix你好');
      expect(split, isNotNull);
      expect(split!.kind, 'full');
      expect(split.prefix, prefix);
      expect(split.rest, '你好');
    });

    test('splits a legacy update snapshot from the user turn', () {
      // Update blocks are no longer written, but conversations frozen by
      // earlier versions still replay them and must stay strippable.
      final prefix =
          '${MemoryPrompts.introUpdateEn}\n'
          '<user_memory_update>\n'
          '<user_profile/>\n'
          '<user_memory type="identity"/>\n'
          '<user_memory type="workflow"/>\n'
          '<user_memory type="voice"/>\n'
          '<user_memory type="instruction"/>\n'
          '</user_memory_update>\n'
          '\n';
      final split = MemoryBlockBuilder.splitInjectedPrefix('${prefix}hello');
      expect(split, isNotNull);
      expect(split!.kind, 'update');
      expect(split.prefix, prefix);
      expect(split.rest, 'hello');
    });

    test('returns null when payload is not a snapshot', () {
      expect(
        MemoryBlockBuilder.splitInjectedPrefix('just a user message'),
        isNull,
      );
    });

    test('legacy summary payload without shown still splits', () {
      final prefix =
          '${MemoryPrompts.introFullZh}\n'
          '<user_profile/>\n'
          '<user_memory type="identity" mode="summary" total="31">\n'
          '- [2026-01-01] old entry\n'
          '${MemoryPrompts.moreHintZh}\n'
          '</user_memory>\n'
          '<user_memory type="workflow"/>\n'
          '<user_memory type="voice"/>\n'
          '<user_memory type="instruction"/>\n'
          '\n';
      final split = MemoryBlockBuilder.splitInjectedPrefix('$prefix你好');
      expect(split, isNotNull);
      expect(split!.kind, 'full');
      expect(split.prefix, prefix);
      expect(split.rest, '你好');
    });
  });
}
