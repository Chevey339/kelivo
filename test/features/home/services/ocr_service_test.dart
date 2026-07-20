import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/home/services/ocr_service.dart';

void main() {
  group('OcrService content-hash cache', () {
    test('memory key is content-hash based', () {
      final service = OcrService();
      service.cacheOcrText('hash-a', 'text-a');

      expect(service.getCachedOcrText('hash-a'), 'text-a');
      expect(service.cacheSize, 1);
      expect(
        OcrService.memoryKeyForContentHash('hash-a'),
        'image_ocr_v1:hash-a',
      );
    });

    test('prefetch keeps >48 SQLite hits in request snapshot', () async {
      var loadCalls = 0;
      final service = OcrService(
        maxCacheEntries: 48,
        resolveContentHashes: (paths) async => {
          for (final path in paths) path: 'hash-$path',
        },
        loadArtifacts: (revisionIds) async {
          loadCalls += 1;
          return {
            'rev-1': {
              for (var i = 0; i < 100; i++) 'hash-/img-$i.png': 'text-$i',
            },
          };
        },
      );

      final paths = [for (var i = 0; i < 100; i++) '/img-$i.png'];
      final session = await service.prefetchPersistedOcr(
        revisionIds: const ['rev-1'],
        imagePaths: paths,
      );

      expect(loadCalls, 1);
      expect(service.cacheSize, 48);
      expect(session.artifactSize, 100);
      expect(service.getCachedOcrText('hash-/img-0.png'), isNull);
    });

    test('concurrent prefetches keep isolated sessions', () async {
      final service = OcrService(
        maxCacheEntries: 2,
        resolveContentHashes: (paths) async => {
          for (final path in paths) path: 'hash-$path',
        },
        loadArtifacts: (revisionIds) async => {
          for (final id in revisionIds)
            id: {
              for (var i = 0; i < 5; i++) 'hash-/$id-$i.png': '$id-$i',
            },
        },
      );

      final sessionA = await service.prefetchPersistedOcr(
        revisionIds: const ['rev-a'],
        imagePaths: [for (var i = 0; i < 5; i++) '/rev-a-$i.png'],
      );
      final sessionB = await service.prefetchPersistedOcr(
        revisionIds: const ['rev-b'],
        imagePaths: [for (var i = 0; i < 5; i++) '/rev-b-$i.png'],
      );

      expect(sessionA.artifactSize, 5);
      expect(sessionB.artifactSize, 5);
      expect(sessionA.artifactTextsByHash['hash-/rev-a-0.png'], 'rev-a-0');
      expect(sessionB.artifactTextsByHash['hash-/rev-b-0.png'], 'rev-b-0');
      expect(sessionA.artifactTextsByHash.containsKey('hash-/rev-b-0.png'), isFalse);
      expect(sessionB.artifactTextsByHash.containsKey('hash-/rev-a-0.png'), isFalse);
    });

    testWidgets(
      'request snapshot prevents full re-OCR after LRU eviction',
      (tester) async {
        var ocrCalls = 0;
        final service = OcrService(
          maxCacheEntries: 2,
          resolveContentHashes: (paths) async => {
            for (final path in paths) path: 'hash-$path',
          },
          loadArtifacts: (revisionIds) async => {
            'rev-1': {
              for (var i = 0; i < 5; i++) 'hash-/img-$i.png': 'text-$i',
            },
          },
          persistArtifact: (revisionId, items) async {},
          ocrExecutor: (paths) async {
            ocrCalls += 1;
            return 'should-not-run';
          },
        );

        final paths = [for (var i = 0; i < 5; i++) '/img-$i.png'];
        final session = await service.prefetchPersistedOcr(
          revisionIds: const ['rev-1'],
          imagePaths: paths,
        );
        expect(service.cacheSize, 2);
        expect(session.artifactSize, 5);

        await tester.pumpWidget(const SizedBox.shrink());
        final context = tester.element(find.byType(SizedBox));

        final text = await service.getOcrTextForImages(
          paths,
          context,
          revisionId: 'rev-1',
          session: session,
        );

        expect(ocrCalls, 0);
        expect(text?.split('\n'), [for (var i = 0; i < 5; i++) 'text-$i']);
      },
    );

    testWidgets(
      'prefetch is one batch; per-message calls reuse hashes and revisions',
      (tester) async {
        var loadCalls = 0;
        var resolveCalls = 0;
        final service = OcrService(
          resolveContentHashes: (paths) async {
            resolveCalls += 1;
            return {for (final path in paths) path: 'hash-$path'};
          },
          loadArtifacts: (revisionIds) async {
            loadCalls += 1;
            return {
              for (final id in revisionIds) id: {'hash-/$id.png': 'text-$id'},
            };
          },
          persistArtifact: (revisionId, items) async {},
          ocrExecutor: (paths) async => 'should-not-run',
        );

        final session = await service.prefetchPersistedOcr(
          revisionIds: const ['rev-1', 'rev-2'],
          imagePaths: const ['/rev-1.png', '/rev-2.png'],
        );
        expect(loadCalls, 1);
        expect(resolveCalls, 1);

        await tester.pumpWidget(const SizedBox.shrink());
        final context = tester.element(find.byType(SizedBox));

        expect(
          await service.getOcrTextForImages(
            const ['/rev-1.png'],
            context,
            revisionId: 'rev-1',
            session: session,
          ),
          'text-rev-1',
        );
        expect(
          await service.getOcrTextForImages(
            const ['/rev-2.png'],
            context,
            revisionId: 'rev-2',
            session: session,
          ),
          'text-rev-2',
        );
        expect(loadCalls, 1);
        expect(resolveCalls, 1);
      },
    );

    testWidgets('memory hit is persisted onto current revision', (
      tester,
    ) async {
      final persisted = <String, Map<String, String>>{};
      final service = OcrService(
        resolveContentHashes: (paths) async => {
          for (final path in paths) path: 'shared-hash',
        },
        loadArtifacts: (ids) async => {
          for (final id in ids) id: persisted[id] ?? const {},
        },
        persistArtifact: (revisionId, items) async {
          persisted[revisionId] = {
            ...persisted[revisionId] ?? const {},
            ...items,
          };
        },
        ocrExecutor: (paths) async => 'should-not-run',
      );

      service.cacheOcrText('shared-hash', 'shared-text');
      final session = await service.prefetchPersistedOcr(
        revisionIds: const ['rev-b'],
        imagePaths: const ['/shared.png'],
      );

      await tester.pumpWidget(const SizedBox.shrink());
      final context = tester.element(find.byType(SizedBox));

      final text = await service.getOcrTextForImages(
        const ['/shared.png'],
        context,
        revisionId: 'rev-b',
        session: session,
      );
      expect(text, 'shared-text');
      expect(persisted['rev-b'], {'shared-hash': 'shared-text'});
    });

    testWidgets('data URL images are hashed and cached', (tester) async {
      final persisted = <String, Map<String, String>>{};
      var ocrCalls = 0;
      const dataUrl = 'data:image/png;base64,aGVsbG8=';
      final service = OcrService(
        resolveContentHashes: (paths) async => {
          for (final path in paths) path: 'data-hash-1',
        },
        loadArtifacts: (ids) async => const {},
        persistArtifact: (revisionId, items) async {
          persisted[revisionId] = {
            ...persisted[revisionId] ?? const {},
            ...items,
          };
        },
        ocrExecutor: (paths) async {
          ocrCalls += 1;
          return 'data-ocr';
        },
      );

      final session = await service.prefetchPersistedOcr(
        revisionIds: const ['rev-1'],
        imagePaths: const [dataUrl],
      );

      await tester.pumpWidget(const SizedBox.shrink());
      final context = tester.element(find.byType(SizedBox));

      expect(
        await service.getOcrTextForImages(
          const [dataUrl],
          context,
          revisionId: 'rev-1',
          session: session,
        ),
        'data-ocr',
      );
      expect(ocrCalls, 1);
      expect(persisted['rev-1'], {'data-hash-1': 'data-ocr'});
      expect(service.getCachedOcrText('data-hash-1'), 'data-ocr');

      expect(
        await service.getOcrTextForImages(
          const [dataUrl],
          context,
          revisionId: 'rev-1',
          session: session,
        ),
        'data-ocr',
      );
      expect(ocrCalls, 1);
    });

    test('prefetch dedupes duplicate image paths before hashing', () async {
      var resolveCalls = 0;
      var hashedPaths = <String>[];
      final service = OcrService(
        resolveContentHashes: (paths) async {
          resolveCalls += 1;
          hashedPaths = List<String>.of(paths);
          return {for (final path in paths) path: 'hash-$path'};
        },
        loadArtifacts: (ids) async => const {},
      );

      await service.prefetchPersistedOcr(
        revisionIds: const ['r1', 'r2'],
        imagePaths: List<String>.filled(100, '/shared.png'),
      );

      expect(resolveCalls, 1);
      expect(hashedPaths, ['/shared.png']);
    });

    test('provider/model/prompt are not part of the memory key', () {
      final service = OcrService();
      service.cacheOcrText('same-hash', 'same-text');
      expect(service.getCachedOcrText('same-hash'), 'same-text');
      expect(
        OcrService.memoryKeyForContentHash('same-hash'),
        isNot(contains('provider')),
      );
    });

    test('LRU evicts oldest memory entries by content hash', () {
      final service = OcrService(maxCacheEntries: 2);
      service.cacheOcrText('h1', 'one');
      service.cacheOcrText('h2', 'two');
      service.cacheOcrText('h3', 'three');
      expect(service.cacheSize, 2);
      expect(service.getCachedOcrText('h1'), isNull);
      expect(service.getCachedOcrText('h2'), 'two');
      expect(service.getCachedOcrText('h3'), 'three');
    });
  });
}
