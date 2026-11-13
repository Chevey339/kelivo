import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:Kelivo/features/settings/logs/request_log_tail_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late File file;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('request_tail_');
    file = File('${temp.path}/logs.txt');
  });
  tearDown(() => temp.delete(recursive: true));

  String event(int time, String value) =>
      '[2026-11-13 12:00:00.${time.toString().padLeft(3, '0')}] $value\n';

  test(
    'merges interleaved requests across byte pages and preserves details',
    () async {
      final content = [
        event(0, '[REQ 1] POST https://example.com/one'),
        event(1, '[REQ 1] headers={\n  "Accept": "中文"\n}'),
        event(2, '[REQ 1] body={"question":"你好"}'),
        event(3, '[REQ 2] GET https://example.com/two'),
        event(4, '[RES 1] status=200'),
        event(5, '[RES 2] status=401'),
        event(6, r'[RES 1] chunk=first\n'),
        event(7, '[RES 2] body={"error":"denied"}'),
        event(8, '[RES 1] chunk=最后'),
        event(9, '[RES 2] done'),
        event(10, '[RES 1] done'),
      ].join();
      await file.writeAsString(content);
      final merged = <int, RequestLogItem>{};
      var cursor = const RequestLogTailCursor();
      var pages = 0;
      RequestLogItem? unfinished;
      do {
        final page = await RequestLogTailReader.readPage(
          path: file.path,
          cursor: cursor,
          maxBytes: 70,
          chunkSize: 7,
        );
        for (final item in page.items) {
          merged[item.entry.sequence] = item;
          if (item.entry.id == 1 && item.start == null) unfinished ??= item;
        }
        cursor = page.cursor;
        pages++;
        if (!page.hasMore) break;
        expect(pages, lessThan(20));
      } while (true);
      expect(pages, greaterThan(2));
      expect(merged, hasLength(2));
      final one = merged.values.singleWhere((e) => e.entry.id == 1);
      final two = merged.values.singleWhere((e) => e.entry.id == 2);
      expect(one.entry.rawUrl, 'https://example.com/one');
      expect(one.entry.statusCode, 200);
      expect(one.entry.hasError, isFalse);
      expect(two.entry.statusCode, 401);
      expect(two.entry.errors.single, contains('denied'));
      expect(one.entry.responseBody, isNull); // Summaries retain no payloads.
      expect(cursor.open, isEmpty);
      for (final item in [one, unfinished!]) {
        final detail = await RequestLogTailReader.readDetail(
          path: file.path,
          item: item,
          elide: true,
        );
        expect(detail.requestHeaders!['Accept'], '中文');
        expect(detail.requestBody, '{"question":"你好"}');
        expect(detail.responseBody, 'first\n最后');
        expect(detail.statusCode, 200);
        expect(detail.errors, isEmpty);
      }
      expect(
        unfinished.start,
        isNull,
      ); // Later pages do not mutate old snapshots.
    },
  );

  test('reused IDs after restart remain distinct, even across pages', () async {
    await file.writeAsString(
      [
        event(0, '[REQ 1] POST https://example.com/old'),
        event(1, '[RES 1] status=500'),
        event(2, '[RES 1] body=old failure'),
        event(3, '[RES 1] done'),
        event(4, '[REQ 1] GET https://example.com/new'),
        event(5, '[RES 1] status=200'),
        event(6, '[RES 1] chunk=new result'),
        event(7, '[RES 1] done'),
      ].join(),
    );
    final merged = <int, RequestLogItem>{};
    var cursor = const RequestLogTailCursor();
    do {
      final page = await RequestLogTailReader.readPage(
        path: file.path,
        cursor: cursor,
        maxBytes: 80,
      );
      for (final item in page.items) {
        merged[item.entry.sequence] = item;
      }
      cursor = page.cursor;
      if (!page.hasMore) break;
    } while (true);
    expect(merged, hasLength(2));
    final items = merged.values.toList()
      ..sort((a, b) => a.end.compareTo(b.end));
    final old = await RequestLogTailReader.readDetail(
      path: file.path,
      item: items[0],
      elide: true,
    );
    final recent = await RequestLogTailReader.readDetail(
      path: file.path,
      item: items[1],
      elide: true,
    );
    expect(old.rawUrl, endsWith('/old'));
    expect(old.responseBody, 'old failure');
    expect(old.statusCode, 500);
    expect(recent.rawUrl, endsWith('/new'));
    expect(recent.responseBody, 'new result');
    expect(recent.statusCode, 200);
  });

  test(
    'first page is bounded even when a single request spans megabytes',
    () async {
      final content = StringBuffer(
        event(0, '[REQ 1] POST https://example.com'),
      );
      for (var i = 0; i < 2000; i++) {
        content.write(event(1, '[RES 1] chunk=${'x' * 1024}'));
      }
      content.write(event(2, '[RES 1] done'));
      await file.writeAsString(content.toString());
      final page = await RequestLogTailReader.readPage(
        path: file.path,
        maxBytes: 16 * 1024,
      );
      expect(page.hasMore, isTrue);
      expect(page.items, hasLength(1));
      expect(page.items.single.start, isNull);
      expect(await file.length() - page.cursor.position!, lessThan(18 * 1024));
      expect(page.items.single.entry.responseBody, isNull);
    },
  );

  test(
    'a selected stream still elides payloads split across log records',
    () async {
      final payload = 'A' * 20000;
      final body = jsonEncode({'url': 'data:image/png;base64,$payload'});
      await file.writeAsString(
        [
          event(0, '[REQ 1] GET https://example.com'),
          event(1, '[RES 1] status=200'),
          event(2, '[RES 1] chunk=${body.substring(0, 9000)}'),
          event(3, '[RES 1] chunk=${body.substring(9000)}'),
          event(4, '[RES 1] done'),
        ].join(),
      );
      final page = await RequestLogTailReader.readPage(
        path: file.path,
        maxBytes: 100,
      );
      final item = page.items.single;
      final path = file.path;
      final detail = await Isolate.run(
        () => RequestLogTailReader.readDetail(
          path: path,
          item: item,
          elide: true,
        ),
      );
      expect(detail.responseBody, contains('<omitted 20000 chars>'));
      expect(detail.attachments.single.base64Chars, 20000);
      final raw = await RequestLogTailReader.readDetail(
        path: path,
        item: item,
        elide: false,
      );
      expect(raw.responseBody, contains(payload));
    },
  );

  test('pagination ignores appends until refreshed', () async {
    await file.writeAsString(
      event(0, '[REQ 1] GET https://example.com/one') +
          event(1, '[REQ 2] GET https://example.com/two'),
    );
    final first = await RequestLogTailReader.readPage(
      path: file.path,
      limit: 1,
    );
    await file.writeAsString(
      event(2, '[REQ 3] GET https://example.com/three'),
      mode: FileMode.append,
    );
    final second = await RequestLogTailReader.readPage(
      path: file.path,
      cursor: first.cursor,
    );
    expect(first.items.single.entry.id, 2);
    expect(second.items.single.entry.id, 1);
    final refreshed = await RequestLogTailReader.readPage(path: file.path);
    expect(refreshed.items.map((e) => e.entry.id), [3, 2, 1]);
  });

  test(
    'empty and malformed logs can exhaust without phantom requests',
    () async {
      await file.writeAsString('');
      expect(
        (await RequestLogTailReader.readPage(path: file.path)).hasMore,
        isFalse,
      );
      await file.writeAsString(
        'garbage\n[2026-11-13 12:00:00.000] unrelated\n',
      );
      final page = await RequestLogTailReader.readPage(path: file.path);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    },
  );

  test('response without a start can still be opened', () async {
    await file.writeAsString(
      event(0, '[RES 8] status=500') +
          event(1, '[RES 8] body=failed').trimRight(),
    );
    final page = await RequestLogTailReader.readPage(
      path: file.path,
      chunkSize: 1,
    );
    final detail = await RequestLogTailReader.readDetail(
      path: file.path,
      item: page.items.single,
      elide: true,
    );
    expect(detail.statusCode, 500);
    expect(detail.responseBody, 'failed');
  });

  test(
    'success status on an earlier page clears a provisional body error',
    () async {
      await file.writeAsString(
        event(0, '[REQ 1] GET https://example.com') +
            event(1, '[RES 1] status=200') +
            event(2, '[RES 1] body=ok'),
      );
      final first = await RequestLogTailReader.readPage(
        path: file.path,
        maxBytes: 2,
      );
      expect(first.items.single.entry.hasError, isTrue);
      final second = await RequestLogTailReader.readPage(
        path: file.path,
        cursor: first.cursor,
      );
      expect(
        second.items.single.entry.sequence,
        first.items.single.entry.sequence,
      );
      expect(second.items.single.entry.hasError, isFalse);
    },
  );
  test(
    'rotated same-name files cannot replace a selected request or older page',
    () async {
      final original =
          event(0, '[REQ 1] GET https://example.com/old') +
          event(1, '[RES 1] status=500') +
          event(2, '[RES 1] body=old failure');
      await file.writeAsString(original);
      final page = await RequestLogTailReader.readPage(
        path: file.path,
        limit: 1,
      );
      final partial = await RequestLogTailReader.readPage(
        path: file.path,
        maxBytes: 1,
      );
      await file.rename('${temp.path}/rotated.txt');
      await file.writeAsString(
        event(3, '[REQ 1] GET https://example.com/new') +
            event(4, '[RES 1] status=200') +
            event(5, '[RES 1] chunk=${'x' * 1000}'),
      );
      await expectLater(
        RequestLogTailReader.readDetail(
          path: file.path,
          item: page.items.single,
          elide: true,
        ),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        RequestLogTailReader.readPage(path: file.path, cursor: partial.cursor),
        throwsA(isA<FileSystemException>()),
      );
      final refreshed = await RequestLogTailReader.readPage(path: file.path);
      expect(refreshed.items.single.entry.rawUrl, endsWith('/new'));
    },
  );

  test('truncation fails rather than combining unrelated offsets', () async {
    await file.writeAsString(
      event(0, '[REQ 1] GET https://example.com/old') +
          event(1, '[RES 1] body=failed'),
    );
    final page = await RequestLogTailReader.readPage(
      path: file.path,
      maxBytes: 1,
    );
    await file.writeAsString('');
    await expectLater(
      RequestLogTailReader.readPage(path: file.path, cursor: page.cursor),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      RequestLogTailReader.readDetail(
        path: file.path,
        item: page.items.single,
        elide: true,
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
  test(
    'error previews honor payload elision before shortening the summary',
    () async {
      final payload = 'A' * 10000;
      final body = jsonEncode({
        'image': 'data:image/png;base64,$payload',
        'error': 'denied',
      });
      await file.writeAsString(
        event(0, '[REQ 1] POST https://example.com') +
            event(1, '[RES 1] status=400') +
            event(2, '[RES 1] body=$body'),
      );
      final hidden = await RequestLogTailReader.readPage(path: file.path);
      expect(
        hidden.items.single.entry.errors.single,
        contains('<omitted 10000 chars>'),
      );
      expect(hidden.items.single.entry.errors.single, contains('denied'));
      final raw = await RequestLogTailReader.readPage(
        path: file.path,
        elide: false,
      );
      expect(raw.items.single.entry.errors.single, contains('A' * 100));
    },
  );
}
