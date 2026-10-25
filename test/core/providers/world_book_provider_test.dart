import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/models/world_book.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessTestHarness harness;
  late WorldBookProvider provider;
  const entry = WorldBookEntry(
    id: 'alpha',
    name: 'Alpha',
    enabled: false,
    content: 'A dragon appears.',
    keywords: ['dragon', '城堡'],
    priority: -20,
    position: WorldBookInjectionPosition.atDepth,
    injectDepth: 0,
    role: WorldBookInjectionRole.assistant,
    useRegex: true,
    caseSensitive: true,
    scanDepth: 12,
    constantActive: true,
    sticky: 3,
    cooldown: 7,
    delay: 2,
  );
  const source = WorldBook(
    id: 'source',
    name: 'Source',
    entries: [
      entry,
      WorldBookEntry(id: 'beta', name: 'Beta', content: 'B'),
      WorldBookEntry(id: 'gamma', name: 'Gamma', content: 'C'),
    ],
  );
  const target = WorldBook(
    id: 'target',
    name: 'Target',
    description: 'Keep this setting',
    enabled: false,
    entries: [WorldBookEntry(id: 'existing', content: 'Existing')],
  );

  setUp(() async {
    harness = await createBusinessTestHarness();
    provider = WorldBookProvider(preferences: harness.preferences);
    addTearDown(provider.dispose);
    await provider.initialize();
    await provider.addBook(source);
    await provider.addBook(target);
    await provider.setActiveBookIds(['source'], assistantId: 'assistant');
    await provider.setBookCollapsed('target', true);
  });

  Future<WorldBookProvider> reload() async {
    final next = WorldBookProvider(
      preferences: BusinessPreferences(harness.repository),
    );
    await next.initialize();
    addTearDown(next.dispose);
    return next;
  }

  for (final sameBook in [false, true]) {
    test(
      'copy preserves every field and ordering, same book: $sameBook',
      () async {
        final destination = sameBook ? 'source' : 'target';
        await provider.transferEntries(
          sourceBookId: 'source',
          targetBookId: destination,
          entryIds: {'gamma', 'alpha'},
          copy: true,
        );
        final saved = await reload();
        final copies = saved
            .getById(destination)!
            .entries
            .skip(sameBook ? 3 : 1)
            .toList();
        expect(copies.map((e) => e.name), ['Alpha', 'Gamma']);
        expect(
          copies.first.toJson()..remove('id'),
          entry.toJson()..remove('id'),
        );
        expect(copies.map((e) => e.id).toSet().length, 2);
        expect(
          copies.any((e) => source.entries.any((old) => e.id == old.id)),
          isFalse,
        );
        expect(
          saved.getById('source')!.entries.take(3).map((e) => e.toJson()),
          source.entries.map((e) => e.toJson()),
        );
        expect(saved.getById('target')!.enabled, isFalse);
        expect(saved.activeBookIdsFor('assistant'), ['source']);
        expect(saved.isBookCollapsed('target'), isTrue);
      },
    );
  }

  test(
    'move persists both books together and retains IDs and settings',
    () async {
      await provider.transferEntries(
        sourceBookId: 'source',
        targetBookId: 'target',
        entryIds: {'gamma', 'alpha'},
        copy: false,
      );
      final saved = await reload();
      expect(saved.getById('source')!.entries.map((e) => e.id), ['beta']);
      expect(saved.getById('target')!.entries.map((e) => e.id), [
        'existing',
        'alpha',
        'gamma',
      ]);
      expect(saved.getById('target')!.entries[1].toJson(), entry.toJson());
      expect(saved.getById('target')!.description, target.description);
      expect(saved.getById('target')!.enabled, isFalse);
      expect(saved.activeBookIdsFor('assistant'), ['source']);
    },
  );

  test(
    'move resolves destination ID conflicts without replacing entries',
    () async {
      await provider.updateBook(
        target.id,
        (current) => current.copyWith(
          entries: [entry.copyWith(content: 'Other content')],
        ),
      );
      await provider.transferEntries(
        sourceBookId: 'source',
        targetBookId: 'target',
        entryIds: {'alpha'},
        copy: false,
      );
      final saved = await reload();
      final entries = saved.getById('target')!.entries;
      expect(entries.first.content, 'Other content');
      expect(entries.last.id, isNot('alpha'));
      expect(entries.last.toJson()..remove('id'), entry.toJson()..remove('id'));
      expect(saved.getById('source')!.entries.map((e) => e.id), [
        'beta',
        'gamma',
      ]);
    },
  );

  test('moving every entry keeps an empty source book', () async {
    await provider.transferEntries(
      sourceBookId: 'source',
      targetBookId: 'target',
      entryIds: {'alpha', 'beta', 'gamma'},
      copy: false,
    );
    final saved = await reload();
    expect(saved.getById('source')!.entries, isEmpty);
    expect(saved.getById('target')!.entries, hasLength(4));
  });

  test(
    'empty selections and same-book moves leave storage untouched',
    () async {
      final before = harness.preferences.getString('world_books_v1');
      await provider.transferEntries(
        sourceBookId: 'source',
        targetBookId: 'target',
        entryIds: {},
        copy: false,
      );
      await provider.transferEntries(
        sourceBookId: 'source',
        targetBookId: 'source',
        entryIds: {'alpha'},
        copy: false,
      );
      expect(harness.preferences.getString('world_books_v1'), before);
    },
  );

  test(
    'stale book and entry selections fail without partial changes',
    () async {
      final before = jsonEncode(provider.books.map((b) => b.toJson()).toList());
      for (final (sourceId, targetId, ids) in [
        ('missing', 'target', {'alpha'}),
        ('source', 'missing', {'alpha'}),
        ('source', 'target', {'alpha', 'missing'}),
      ]) {
        await expectLater(
          provider.transferEntries(
            sourceBookId: sourceId,
            targetBookId: targetId,
            entryIds: ids,
            copy: false,
          ),
          throwsStateError,
        );
      }
      expect(
        jsonEncode(provider.books.map((b) => b.toJson()).toList()),
        before,
      );
      expect(harness.preferences.getString('world_books_v1'), before);
    },
  );

  test(
    'failed persistence rolls back the move in memory and storage',
    () async {
      final before = harness.preferences.getString('world_books_v1');
      await harness.preferences.runWithRestoreWriteFence(() async {});
      await expectLater(
        provider.transferEntries(
          sourceBookId: 'source',
          targetBookId: 'target',
          entryIds: {'alpha'},
          copy: false,
        ),
        throwsStateError,
      );
      expect(
        jsonEncode(provider.books.map((b) => b.toJson()).toList()),
        before,
      );
      expect(harness.preferences.getString('world_books_v1'), before);
    },
  );
  for (final fail in [false, true]) {
    test('concurrent moves preserve both books, save fails: $fail', () async {
      final before = harness.preferences.getString('world_books_v1');
      if (fail) {
        await harness.preferences.runWithRestoreWriteFence(() async {});
      }
      final operations = [
        for (final id in ['alpha', 'beta'])
          provider.transferEntries(
            sourceBookId: 'source',
            targetBookId: 'target',
            entryIds: {id},
            copy: false,
          ),
      ];
      if (fail) {
        await Future.wait(
          operations.map(
            (operation) => expectLater(operation, throwsStateError),
          ),
        );
        expect(
          jsonEncode(provider.books.map((b) => b.toJson()).toList()),
          before,
        );
        expect(harness.preferences.getString('world_books_v1'), before);
      } else {
        await Future.wait(operations);
        final saved = await reload();
        expect(saved.getById('source')!.entries.map((e) => e.id), ['gamma']);
        expect(saved.getById('target')!.entries.map((e) => e.id), [
          'existing',
          'alpha',
          'beta',
        ]);
      }
    });
  }

  for (final action in ['edit', 'add', 'reload']) {
    test('$action during a move cannot overwrite the moved entries', () async {
      Future<void>? followUp;
      void onChanged() {
        if (followUp != null ||
            provider.getById('source')!.entries.length != 2) {
          return;
        }
        provider.removeListener(onChanged);
        followUp = switch (action) {
          'edit' => provider.updateBook(
            'target',
            (current) => current.copyWith(
              enabled: true,
              entries: current.entries
                  .where((e) => e.id != 'existing')
                  .toList(),
            ),
          ),
          'add' => provider.addBook(const WorldBook(id: 'new', name: 'New')),
          _ => provider.loadAll(),
        };
      }

      provider.addListener(onChanged);
      await provider.transferEntries(
        sourceBookId: 'source',
        targetBookId: 'target',
        entryIds: {'alpha'},
        copy: false,
      );
      expect(followUp, isNotNull);
      await followUp;
      expect(provider.getById('source')!.entries.map((e) => e.id), [
        'beta',
        'gamma',
      ]);
      final saved = await reload();
      expect(saved.getById('source')!.entries.map((e) => e.id), [
        'beta',
        'gamma',
      ]);
      expect(
        saved.getById('target')!.entries.map((e) => e.id),
        action == 'edit' ? ['alpha'] : ['existing', 'alpha'],
      );
      if (action == 'add') expect(saved.getById('new')!.name, 'New');
    });
  }

  test('a move queued after adding a book retains the new book', () async {
    final addition = provider.addBook(const WorldBook(id: 'new', name: 'New'));
    final move = provider.transferEntries(
      sourceBookId: 'source',
      targetBookId: 'target',
      entryIds: {'alpha'},
      copy: false,
    );
    await Future.wait([addition, move]);
    final saved = await reload();
    expect(saved.getById('new')!.name, 'New');
    expect(saved.getById('source')!.entries.map((e) => e.id), [
      'beta',
      'gamma',
    ]);
    expect(saved.getById('target')!.entries.last.id, 'alpha');
  });

  test('a failed move rolls back before a queued entry toggle', () async {
    await harness.preferences.runWithRestoreWriteFence(() async {});
    Future<void>? toggleCheck;
    void onChanged() {
      if (provider.getById('source')!.entries.length != 2) return;
      provider.removeListener(onChanged);
      toggleCheck = expectLater(
        provider.setEntryEnabled('source', 'beta', false),
        throwsStateError,
      );
    }

    provider.addListener(onChanged);
    await expectLater(
      provider.transferEntries(
        sourceBookId: 'source',
        targetBookId: 'target',
        entryIds: {'alpha'},
        copy: false,
      ),
      throwsStateError,
    );
    expect(toggleCheck, isNotNull);
    await toggleCheck;
    expect(provider.getById('source')!.entries.map((e) => e.id), [
      'alpha',
      'beta',
      'gamma',
    ]);
    expect(provider.getById('target')!.entries.map((e) => e.id), ['existing']);
  });

  for (final action in ['delete entry', 'add entry', 'rename book']) {
    test('queued destination $action retains incoming entries', () async {
      WorldBook update(WorldBook current) => switch (action) {
        'delete entry' => current.copyWith(
          entries: current.entries.where((e) => e.id != 'existing').toList(),
        ),
        'add entry' => current.copyWith(
          entries: [
            ...current.entries,
            const WorldBookEntry(id: 'added', content: 'Added'),
          ],
        ),
        _ => current.copyWith(name: 'Renamed'),
      };
      final move = provider.transferEntries(
        sourceBookId: 'source',
        targetBookId: 'target',
        entryIds: {'alpha'},
        copy: false,
      );
      final edit = provider.updateBook('target', update);
      await Future.wait([move, edit]);
      final saved = await reload();
      expect(saved.getById('source')!.entries.map((e) => e.id), [
        'beta',
        'gamma',
      ]);
      expect(
        saved
            .getById('target')!
            .entries
            .where((e) => e.id == 'alpha')
            .single
            .toJson(),
        entry.toJson(),
      );
      if (action == 'delete entry') {
        expect(saved.getById('target')!.entries, hasLength(1));
      } else if (action == 'add entry') {
        expect(saved.getById('target')!.entries.map((e) => e.id), [
          'existing',
          'alpha',
          'added',
        ]);
      } else {
        expect(saved.getById('target')!.name, 'Renamed');
      }
    });
  }
}
