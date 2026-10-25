import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/world_book.dart';
import 'package:Kelivo/core/services/world_book_activation.dart';
import 'package:Kelivo/features/world_book/utils/world_book_import.dart';

Map<String, dynamic> tavernEntry(Map<String, dynamic> overrides) => {
  'uid': 0,
  'key': ['dragon'],
  'keysecondary': <String>[],
  'comment': 'Dragon',
  'content': 'A dragon lives in the mountains.',
  'constant': false,
  'selective': true,
  'order': 100,
  'position': 0,
  'disable': false,
  'probability': 100,
  'useProbability': true,
  'depth': 4,
  'role': 0,
  'scanDepth': null,
  'caseSensitive': null,
  'matchWholeWords': null,
  'sticky': null,
  'cooldown': null,
  'delay': null,
  ...overrides,
};

WorldBookImportResult importEntries(List<Map<String, dynamic>> entries) {
  // Exercise JSON-decoded maps, as both file pickers do.
  return parseWorldBookImport(
    jsonDecode(
      jsonEncode({
        'entries': {for (var i = 0; i < entries.length; i++) '$i': entries[i]},
      }),
    ),
    fileName: r'C:\exports\山海世界.JSON',
  )!;
}

void main() {
  test('preserves existing Kelivo and RikkaHub exports', () {
    const original = WorldBook(
      id: 'existing',
      name: 'Kelivo book',
      description: 'Description',
      enabled: false,
      entries: [
        WorldBookEntry(
          id: 'entry',
          name: 'Entry',
          content: 'Content',
          keywords: ['dragon'],
          sticky: 3,
          cooldown: 2,
          delay: 1,
          role: WorldBookInjectionRole.assistant,
          injectDepth: 0,
        ),
      ],
    );
    for (final json in [
      original.toJson(),
      {'version': 1, 'type': 'lorebook', 'data': original.toJson()},
    ]) {
      final result = parseWorldBookImport(json, fileName: 'other.json')!;
      expect(result.book.toJson(), original.toJson());
      expect(result.unsupportedEntryCount, 0);
    }
  });

  test('imports supported ST fields, filename and persisted roles', () {
    final result = importEntries([
      tavernEntry({
        'uid': 12,
        'displayIndex': 1,
        'disable': true,
        'position': 1,
      }),
      tavernEntry({
        'uid': 42,
        'displayIndex': 0,
        'comment': '山海经',
        'content': '第一行\n第二行',
        'key': ['龙', '山海'],
        'constant': true,
        'order': 250,
        'position': 4,
        'depth': 0,
        'role': 1,
        'scanDepth': 7,
        'caseSensitive': true,
        'delay': 1,
      }),
    ]);
    final book = result.book;
    expect(book.name, '山海世界');
    expect(book.entries.map((e) => e.id), ['42', '12']);
    final entry = book.entries.first;
    expect(entry.name, '山海经');
    expect(entry.content, '第一行\n第二行');
    expect(entry.keywords, ['龙', '山海']);
    expect(entry.enabled, isTrue);
    expect(entry.constantActive, isTrue);
    expect(entry.priority, -250);
    expect(entry.position, WorldBookInjectionPosition.atDepth);
    expect(entry.injectDepth, 0);
    expect(entry.role, WorldBookInjectionRole.user);
    expect(entry.scanDepth, 7);
    expect(entry.caseSensitive, isTrue);
    expect([entry.sticky, entry.cooldown, entry.delay], [0, 0, 1]);
    expect(book.entries.last.enabled, isFalse);
    expect(
      book.entries.last.position,
      WorldBookInjectionPosition.afterSystemPrompt,
    );
    expect(result.unsupportedEntryCount, 0);
    expect(WorldBook.fromJson(book.toJson()).toJson(), book.toJson());
  });

  test('uses explicit name and primary key as the fallback entry title', () {
    final result = parseWorldBookImport({
      'name': 'Named world',
      'description': 'Setting',
      'entries': {
        '7': tavernEntry({'comment': '', 'uid': null}),
      },
    }, fileName: 'ignored.json')!;
    expect(result.book.name, 'Named world');
    expect(result.book.description, 'Setting');
    expect(result.book.entries.single.name, 'dragon');
    expect(result.book.entries.single.id, '7');
    expect(result.book.entries.single.scanDepth, 2);
  });

  test('retains ST insertion order when entries activate', () {
    final result = importEntries([
      tavernEntry({'order': 250, 'content': 'LATE'}),
      tavernEntry({'order': 100, 'content': 'EARLY'}),
    ]);
    final activated = WorldBookActivation.evaluate(
      books: [result.book],
      scanMessages: [
        {'role': 'user', 'content': 'dragon'},
      ],
      history: const [],
    );
    expect(activated.entries.map((e) => e.content), ['EARLY', 'LATE']);
  });

  test('same-order prompts use reverse JS key order, not displayIndex', () {
    final result = parseWorldBookImport({
      'entries': {
        for (final key in [
          '10',
          'named',
          '2',
          '01',
          '1',
          '4294967295',
          'later',
          '4294967294',
        ])
          key: tavernEntry({'content': key, 'displayIndex': 0}),
      },
    }, fileName: 'Order.json')!;
    final activated = WorldBookActivation.evaluate(
      books: [result.book],
      scanMessages: [
        {'role': 'user', 'content': 'dragon'},
      ],
      history: const [],
    );
    expect(activated.entries.map((e) => e.content), [
      'later',
      '4294967295',
      '01',
      'named',
      '4294967294',
      '10',
      '2',
      '1',
    ]);
  });

  test('keeps regex source for review without changing matching semantics', () {
    for (final keyword in [r'/dragon\d+/ig', r'/dragon$/', r'/Dragon\d+/']) {
      final result = importEntries([
        tavernEntry({
          'key': [keyword, 'a.b'],
        }),
      ]);
      final entry = result.book.entries.single;
      expect(result.unsupportedEntryCount, 1);
      expect(entry.enabled, isFalse);
      expect(entry.keywords, [keyword, 'a.b']);
      expect(
        WorldBookActivation.evaluate(
          books: [result.book],
          scanMessages: const [
            {'role': 'user', 'content': 'old'},
            {'role': 'assistant', 'content': 'dragon'},
          ],
          history: const [],
        ).entries,
        isEmpty,
      );
    }
  });

  test('preserves unsupported timer values while disabling the entry', () {
    final result = importEntries([
      tavernEntry({'sticky': 2, 'cooldown': 3}),
    ]);
    final entry = result.book.entries.single;
    expect(result.unsupportedEntryCount, 1);
    expect(entry.enabled, isFalse);
    expect([entry.sticky, entry.cooldown], [2, 3]);
  });

  test('mixed roles at the same depth require review regardless of order', () {
    final result = importEntries([
      tavernEntry({'position': 4, 'role': 1, 'depth': 0, 'order': 50}),
      tavernEntry({'position': 4, 'role': 2, 'depth': 0, 'order': 100}),
      tavernEntry({'position': 4, 'role': 2, 'depth': 1}),
    ]);
    expect(result.unsupportedEntryCount, 2);
    expect(result.book.enabledEntryCount, 1);
    expect(result.book.entries.singleWhere((e) => e.enabled).injectDepth, 1);
  });

  final unsupportedCases = <String, Map<String, dynamic>>{
    'activation decorators': {'content': '@@dont_activate\nSecret lore'},
    'fallback decorators': {
      'content': '@@unknown\n@@@dont_activate\nSecret lore',
      'constant': true,
    },
    'content macros': {
      'content': '{{getvar::current_location}}',
      'constant': true,
    },
    'keyword macros': {
      'key': ['{{char}}'],
    },
    'legacy content macros': {'content': '<USER> meets <BOT> in <GROUP>.'},
    'legacy keyword macros': {
      'key': ['<char>', '<charifnotgroup>'],
    },
    'sticky timing': {'sticky': 2},
    'cooldown timing': {'cooldown': 2},
    'out of range delay': {'delay': 10001},
    'secondary keyword filters': {
      'keysecondary': ['mountain'],
    },
    'probability': {'probability': 50},
    'inclusion groups': {'group': 'creature'},
    'vector matching': {'vectorized': true},
    'whole word matching': {'matchWholeWords': true},
    'recursion delay': {'delayUntilRecursion': 1},
    'character filters': {
      'characterFilter': {
        'names': ['Alice'],
      },
    },
    'generation triggers': {
      'triggers': ['normal'],
    },
    'author notes': {'position': 2},
    'example messages': {'position': 5},
    'outlets': {'position': 7},
    'unknown positions': {'position': 9},
    'unknown roles': {'position': 4, 'role': 9},
    'inline system role': {'position': 4, 'role': 0},
    'trailing assistant prefill': {'position': 4, 'role': 2, 'depth': 0},
    'cross-message keywords': {
      'key': ['one\ntwo'],
    },
    'unrepresentable scan depth': {'scanDepth': 0},
    'unrepresentable injection depth': {'position': 4, 'role': 1, 'depth': 201},
    'mixed regex case rules': {
      'key': ['/dragon/', 'literal'],
    },
    'regex flags': {
      'key': ['/dragon/m'],
    },
  };
  for (final item in unsupportedCases.entries) {
    test(
      'keeps content but disables ${item.key} instead of changing activation',
      () {
        final result = importEntries([tavernEntry(item.value)]);
        expect(result.unsupportedEntryCount, 1);
        final entry = result.book.entries.single;
        expect(entry.enabled, isFalse);
        expect(
          entry.content,
          item.value['content'] ?? 'A dragon lives in the mountains.',
        );
        expect(WorldBookActivation.matches(entry, 'dragon'), isFalse);
      },
    );
  }

  test('keeps slash-delimited literals that ST does not treat as regexes', () {
    for (final keyword in [
      '/folder/file',
      '/one/two/',
      '/[/',
      '/dragon/ii',
      '//',
    ]) {
      final result = importEntries([
        tavernEntry({
          'key': [keyword],
        }),
      ]);
      final entry = result.book.entries.single;
      expect(result.unsupportedEntryCount, 0);
      expect(entry.useRegex, isFalse);
      expect(entry.keywords, [keyword]);
      expect(WorldBookActivation.matches(entry, keyword), isTrue);
    }
  });

  test('ignores inactive filters and preserves supported entries', () {
    final result = importEntries([
      tavernEntry({
        'selective': false,
        'keysecondary': ['mountain'],
      }),
      tavernEntry({
        'constant': true,
        'keysecondary': ['mountain'],
        'matchWholeWords': true,
        'vectorized': true,
        'matchPersonaDescription': true,
        'key': [r'/dragon$/', '{{char}}'],
      }),
      tavernEntry({'useProbability': false, 'probability': 0}),
      tavernEntry({'excludeRecursion': true, 'preventRecursion': true}),
      tavernEntry({'disable': true}),
    ]);
    expect(result.unsupportedEntryCount, 0);
    expect(result.book.enabledEntryCount, 4);
    expect(result.book.entries.first.enabled, isFalse);
  });

  test(
    'rejects malformed imports atomically instead of importing empty data',
    () {
      for (final invalid in <Object?>[
        null,
        [],
        {},
        {
          'data': {'name': 'unrelated data'},
        },
        {'entries': 'invalid'},
        {
          'entries': [null],
        },
        {
          'entries': {'0': tavernEntry({}), '1': 'invalid'},
        },
        {
          'entries': {
            '0': tavernEntry({'content': 12}),
          },
        },
        {
          'entries': {
            '0': tavernEntry({
              'key': [12],
            }),
          },
        },
      ]) {
        expect(parseWorldBookImport(invalid, fileName: 'invalid.json'), isNull);
      }
      expect(
        parseWorldBookImport({
          'entries': {},
        }, fileName: 'empty.json')!.book.entries,
        isEmpty,
      );
    },
  );

  test('normalizes duplicate IDs without replacing existing books', () {
    const book = WorldBook(
      id: 'existing',
      entries: [
        WorldBookEntry(id: 'one'),
        WorldBookEntry(id: 'one'),
        WorldBookEntry(id: ''),
      ],
    );
    final normalized = normalizeImportedWorldBook(
      book,
      existingBookIds: {'existing'},
    );
    expect(normalized.id, isNot('existing'));
    expect(normalized.entries.map((e) => e.id).toSet(), hasLength(3));
    expect(normalized.entries.every((e) => e.id.isNotEmpty), isTrue);
    expect(normalized.entries.first.id, 'one');
  });
}
