import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/world_book.dart';
import 'package:Kelivo/core/services/world_book_activation.dart';

void main() {
  const entry = WorldBookEntry(
    id: 'entry',
    content: 'LORE',
    keywords: ['dragon'],
    scanDepth: 1,
  );

  test('sticky, cooldown and delay survive JSON and copyWith', () {
    final book = WorldBook(
      id: 'book',
      entries: [entry.copyWith(sticky: 3, cooldown: 2, delay: 2)],
    );
    final decoded = WorldBook.fromJson(
      jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.entries.single.copyWith(name: 'renamed').toJson(), {
      ...book.entries.single.toJson(),
      'name': 'renamed',
    });
    expect(WorldBookEntry.fromJson({'id': 'default'}).sticky, 0);
    expect(WorldBookEntry.fromJson({'id': 'negative', 'delay': -10}).delay, 0);
  });

  test(
    'sticky expires into cooldown without refreshing on repeated matches',
    () {
      final timed = entry.copyWith(sticky: 3, cooldown: 2, delay: 2);
      final history = <Map<String, dynamic>>[];
      var state = <String, dynamic>{};
      final active = <bool>[];
      for (var i = 0; i < 8; i++) {
        history.add({
          'role': i.isEven ? 'user' : 'assistant',
          'content': 'dragon',
        });
        final result = WorldBookActivation.evaluate(
          books: [
            WorldBook(id: 'book', entries: [timed]),
          ],
          scanMessages: history,
          history: history,
          previous: state,
        );
        active.add(result.entries.isNotEmpty);
        state = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(result.state)) as Map,
        );
        final retry = WorldBookActivation.evaluate(
          books: [
            WorldBook(id: 'book', entries: [timed]),
          ],
          scanMessages: history,
          history: history,
          previous: state,
        );
        expect(
          retry.entries.isNotEmpty,
          active.last,
          reason: 'retry at message ${i + 1}',
        );
        expect(retry.state, state);
      }
      expect(active, [false, true, true, true, true, false, false, true]);
    },
  );

  test('sticky remains active after the keyword leaves the scan window', () {
    final timed = entry.copyWith(sticky: 2);
    final history = <Map<String, dynamic>>[
      {'role': 'user', 'content': 'dragon'},
    ];
    var state = WorldBookActivation.evaluate(
      books: [
        WorldBook(id: 'book', entries: [timed]),
      ],
      scanMessages: history,
      history: history,
    ).state;
    for (var i = 1; i <= 3; i++) {
      history.add({
        'role': i.isOdd ? 'assistant' : 'user',
        'content': 'unrelated',
      });
      final result = WorldBookActivation.evaluate(
        books: [
          WorldBook(id: 'book', entries: [timed]),
        ],
        scanMessages: history,
        history: history,
        previous: state,
      );
      expect(result.entries.isNotEmpty, i <= 2);
      state = result.state;
    }
  });

  test('cooldown alone allows the triggering request and its retry', () {
    final timed = entry.copyWith(cooldown: 2);
    final history = <Map<String, dynamic>>[];
    var state = <String, dynamic>{};
    for (var i = 0; i < 4; i++) {
      history.add({'role': 'user', 'content': 'dragon'});
      final result = WorldBookActivation.evaluate(
        books: [
          WorldBook(id: 'book', entries: [timed]),
        ],
        scanMessages: history,
        history: history,
        previous: state,
      );
      expect(result.entries.isNotEmpty, i == 0 || i == 3);
      state = result.state;
    }
  });

  test(
    'history edits, rewinds and entry edits invalidate existing effects',
    () {
      final timed = entry.copyWith(sticky: 5);
      final books = [
        WorldBook(id: 'book', entries: [timed]),
      ];
      final history = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'dragon'},
      ];
      final initial = WorldBookActivation.evaluate(
        books: books,
        scanMessages: history,
        history: history,
      );
      final progressed = [
        ...history,
        {'role': 'assistant', 'content': 'away'},
      ];
      final active = WorldBookActivation.evaluate(
        books: books,
        scanMessages: progressed,
        history: progressed,
        previous: initial.state,
      );
      expect(active.entries, hasLength(1));
      final changed = [
        {'role': 'user', 'content': 'away'},
        progressed.last,
      ];
      expect(
        WorldBookActivation.evaluate(
          books: books,
          scanMessages: changed,
          history: changed,
          previous: active.state,
        ).entries,
        isEmpty,
      );
      expect(
        WorldBookActivation.evaluate(
          books: books,
          scanMessages: changed.take(1).toList(),
          history: changed.take(1).toList(),
          previous: active.state,
        ).entries,
        isEmpty,
      );
      expect(
        WorldBookActivation.evaluate(
          books: [
            WorldBook(
              id: 'book',
              entries: [timed.copyWith(content: 'edited')],
            ),
          ],
          scanMessages: progressed,
          history: progressed,
          previous: active.state,
        ).entries,
        isEmpty,
      );
      expect(
        WorldBookActivation.evaluate(
          books: [],
          scanMessages: progressed,
          history: progressed,
          previous: active.state,
        ).state['effects'],
        isEmpty,
      );
    },
  );

  test(
    'timed effects are isolated by book and the conversation state supplied',
    () {
      final books = [
        WorldBook(id: 'a', entries: [entry.copyWith(sticky: 3)]),
        WorldBook(
          id: 'b',
          entries: [
            entry.copyWith(content: 'other', keywords: ['castle']),
          ],
        ),
      ];
      final history = [
        {'role': 'user', 'content': 'dragon'},
      ];
      final activated = WorldBookActivation.evaluate(
        books: books,
        scanMessages: history,
        history: history,
      );
      final next = [
        ...history,
        {'role': 'assistant', 'content': 'away'},
      ];
      expect(
        WorldBookActivation.evaluate(
          books: books,
          scanMessages: next,
          history: next,
          previous: activated.state,
        ).entries.map((e) => e.content),
        ['LORE'],
      );
      expect(
        WorldBookActivation.evaluate(
          books: books,
          scanMessages: next,
          history: next,
        ).entries,
        isEmpty,
      );
    },
  );

  test('default matching and priority ordering remain stable', () {
    final items = [
      entry.copyWith(id: 'low', constantActive: true),
      entry.copyWith(
        id: 'first',
        priority: 10,
        keywords: ['[', 'DRAGON'],
        useRegex: true,
      ),
      entry.copyWith(id: 'second', priority: 10),
      entry.copyWith(id: 'disabled', constantActive: true, enabled: false),
      entry.copyWith(id: 'empty', content: '', constantActive: true),
      entry.copyWith(id: 'case', caseSensitive: true, keywords: ['DRAGON']),
    ];
    final messages = [
      {'role': 'user', 'content': 'dragon'},
    ];
    expect(
      WorldBookActivation.evaluate(
        books: [WorldBook(id: 'book', entries: items)],
        scanMessages: messages,
        history: messages,
      ).entries.map((e) => e.id),
      ['first', 'second', 'low'],
    );
  });
}
