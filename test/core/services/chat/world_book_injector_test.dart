import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/world_book.dart';
import 'package:Kelivo/core/services/chat/world_book_injector.dart';

WorldBook _book({
  required String id,
  bool enabled = true,
  List<WorldBookEntry> entries = const <WorldBookEntry>[],
}) {
  return WorldBook(id: id, enabled: enabled, entries: entries);
}

void main() {
  group('applyWorldBookInjections', () {
    test('does nothing when there are no active books', () {
      final messages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'hello'},
      ];
      applyWorldBookInjections(
        messages,
        books: const <WorldBook>[],
        activeBookIds: const <String>[],
      );
      expect(messages, hasLength(1));
    });

    test('skips books that are disabled or not active', () {
      final messages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'cat'},
      ];
      applyWorldBookInjections(
        messages,
        books: [
          _book(
            id: 'b1',
            enabled: false,
            entries: const [
              WorldBookEntry(
                id: 'e1',
                content: 'should not appear',
                constantActive: true,
              ),
            ],
          ),
          _book(
            id: 'b2',
            entries: const [
              WorldBookEntry(
                id: 'e2',
                content: 'inactive book entry',
                constantActive: true,
              ),
            ],
          ),
        ],
        activeBookIds: const ['b1'],
      );
      // b1 is disabled, b2 is not in activeBookIds -> nothing injected.
      expect(messages, hasLength(1));
    });

    test('constant-active entry merges after the system prompt', () {
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': 'base'},
        {'role': 'user', 'content': 'hi'},
      ];
      applyWorldBookInjections(
        messages,
        books: [
          _book(
            id: 'b1',
            entries: const [
              WorldBookEntry(
                id: 'e1',
                content: 'world fact',
                constantActive: true,
              ),
            ],
          ),
        ],
        activeBookIds: const ['b1'],
      );
      final system = messages.firstWhere((m) => m['role'] == 'system');
      expect(system['content'], 'base\nworld fact');
    });

    test('keyword entry triggers only when the keyword is present', () {
      List<Map<String, dynamic>> run(String userContent) {
        final messages = <Map<String, dynamic>>[
          {'role': 'user', 'content': userContent},
        ];
        applyWorldBookInjections(
          messages,
          books: [
            _book(
              id: 'b1',
              entries: const [
                WorldBookEntry(
                  id: 'e1',
                  content: 'dragon lore',
                  position: WorldBookInjectionPosition.topOfChat,
                  keywords: ['dragon'],
                ),
              ],
            ),
          ],
          activeBookIds: const ['b1'],
        );
        return messages;
      }

      final withKeyword = run('tell me about the dragon');
      expect(
        withKeyword.any(
          (m) => (m['content'] as String).contains('dragon lore'),
        ),
        isTrue,
      );

      final withoutKeyword = run('tell me about cats');
      expect(
        withoutKeyword.any(
          (m) => (m['content'] as String).contains('dragon lore'),
        ),
        isFalse,
      );
    });

    test('top-of-chat user injection is wrapped in a system tag', () {
      final messages = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'hi'},
      ];
      applyWorldBookInjections(
        messages,
        books: [
          _book(
            id: 'b1',
            entries: const [
              WorldBookEntry(
                id: 'e1',
                content: 'top note',
                position: WorldBookInjectionPosition.topOfChat,
                role: WorldBookInjectionRole.user,
                constantActive: true,
              ),
            ],
          ),
        ],
        activeBookIds: const ['b1'],
      );
      expect(messages.first['role'], 'user');
      expect(messages.first['content'], '<system>\ntop note\n</system>');
    });
  });
}
