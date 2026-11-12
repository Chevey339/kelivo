import 'package:Kelivo/core/services/storage/attachment_file_lock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'idle lock releases its completed scheduler and can run in a new zone',
    () {
      for (var i = 0; i < 2; i++) {
        fakeAsync((async) {
          var completed = false;
          AttachmentFileLock.synchronized(
            () async => i,
          ).then((_) => completed = true);
          async.flushMicrotasks();
          expect(completed, isTrue);
        });
      }
    },
  );

  test('queued waiters keep exclusive FIFO ownership through errors', () async {
    final first = await AttachmentFileLock.acquire();
    final order = <int>[];
    final failed = AttachmentFileLock.synchronized(() async {
      order.add(2);
      throw StateError('test failure');
    });
    final failure = expectLater(failed, throwsStateError);
    final third = AttachmentFileLock.synchronized(() async => order.add(3));
    await Future<void>.delayed(Duration.zero);
    expect(order, isEmpty);
    first.release();
    first.release();
    await failure;
    await third;
    expect(order, [2, 3]);
  });
}
