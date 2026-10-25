import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/home/services/draft_token_counter.dart';

void main() {
  test('typing only counts the last draft after the quiet period', () {
    fakeAsync((async) {
      final calls = <String>[];
      final published = <int>[];
      final counter = DraftTokenCounter(
        onCountChanged: published.add,
        estimate: (text) {
          calls.add(text);
          return Future.value(text.length);
        },
      );
      for (final text in ['first', 'second', 'latest']) {
        counter.update(text);
        async.elapse(const Duration(milliseconds: 100));
      }
      expect(calls, isEmpty);
      async.elapse(const Duration(milliseconds: 99));
      expect(calls, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(calls, ['latest']);
      expect(published, [6]);
      counter.dispose();
    });
  });

  test(
    'one running worker skips superseded edits and publishes only the latest',
    () {
      fakeAsync((async) {
        final calls = <String>[];
        final jobs = <Completer<int>>[];
        final published = <int>[];
        final counter = DraftTokenCounter(
          onCountChanged: published.add,
          estimate: (text) {
            calls.add(text);
            final job = Completer<int>();
            jobs.add(job);
            return job.future;
          },
        );
        counter.update('running');
        async.elapse(const Duration(milliseconds: 200));
        for (var i = 0; i < 100; i++) {
          counter.update('edit $i');
        }
        async.elapse(const Duration(milliseconds: 200));
        expect(calls, ['running']);
        jobs.first.complete(100);
        async.flushMicrotasks();
        expect(calls, ['running', 'edit 99']);
        expect(published, isEmpty);
        jobs.last.complete(200);
        async.flushMicrotasks();
        expect(published, [200]);
        expect(counter.tokens, 200);
        counter.dispose();
      });
    },
  );

  test('clear is immediate and a late worker cannot restore the old draft', () {
    fakeAsync((async) {
      final pending = Completer<int>();
      final published = <int>[];
      final counter = DraftTokenCounter(
        onCountChanged: published.add,
        estimate: (text) =>
            text == 'initial' ? Future.value(20) : pending.future,
      );
      counter.update('initial');
      async.elapse(const Duration(milliseconds: 200));
      expect(counter.tokens, 20);
      counter.update('long draft');
      async.elapse(const Duration(milliseconds: 200));
      counter.update('');
      expect(counter.tokens, 0);
      var cleared = false;
      counter.flush().then((_) => cleared = true);
      async.flushMicrotasks();
      expect(cleared, isTrue);
      pending.complete(9000);
      async.flushMicrotasks();
      expect(published, [20, 0]);
      counter.dispose();
    });
  });

  test(
    'flush observes the latest edit while an older estimate is running',
    () async {
      final jobs = <Completer<int>>[];
      final counter = DraftTokenCounter(
        onCountChanged: (_) {},
        estimate: (_) {
          final job = Completer<int>();
          jobs.add(job);
          return job.future;
        },
      );
      addTearDown(counter.dispose);
      counter.update('first');
      final first = counter.flush();
      counter.update('latest');
      final latest = counter.flush();
      jobs.first.complete(10);
      await Future<void>.delayed(Duration.zero);
      expect(jobs, hasLength(2));
      jobs.last.complete(30);
      await Future.wait([first, latest]);
      expect(counter.tokens, 30);
    },
  );

  test('dispose cancels pending work and ignores running results', () {
    fakeAsync((async) {
      final job = Completer<int>();
      var calls = 0;
      final published = <int>[];
      final counter = DraftTokenCounter(
        onCountChanged: published.add,
        estimate: (_) {
          calls++;
          return job.future;
        },
      );
      counter.update('running');
      async.elapse(const Duration(milliseconds: 200));
      counter.update('pending');
      counter.dispose();
      job.complete(42);
      async.elapse(const Duration(seconds: 1));
      expect(calls, 1);
      expect(published, isEmpty);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('failed background estimate can be retried by a later edit', () async {
    final counter = DraftTokenCounter(
      onCountChanged: (_) {},
      estimate: (text) => text == 'bad'
          ? Future.error(StateError('worker failed'))
          : Future.value(5),
    );
    addTearDown(counter.dispose);
    counter.update('bad');
    await expectLater(counter.flush(), throwsStateError);
    counter.update('good');
    await counter.flush();
    expect(counter.tokens, 5);
  });

  test(
    'default background worker produces the complete long-draft count',
    () async {
      final counter = DraftTokenCounter(onCountChanged: (_) {});
      addTearDown(counter.dispose);
      counter.update(List.filled(50000, 'word').join(' '));
      await counter.flush();
      expect(counter.tokens, 50000);
    },
  );
}
