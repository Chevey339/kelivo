import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/features/home/services/input_draft_persistence.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('InputDraftPersistence', () {
    test('restore returns null when nothing saved', () async {
      final p = InputDraftPersistence();
      final result = await p.restore();
      expect(result, isNull);
    });

    test('save text then restore returns same text', () async {
      final p = InputDraftPersistence();
      final data = ChatInputData(text: 'hello world');
      p.scheduleSave(data);
      await Future.delayed(const Duration(milliseconds: 900));
      final result = await p.restore();
      expect(result, isNotNull);
      expect(result!.text, 'hello world');
      expect(result.imagePaths, isEmpty);
      expect(result.documents, isEmpty);
    });

    test('save text with images and documents roundtrip', () async {
      final p = InputDraftPersistence();
      final data = ChatInputData(
        text: 'multi modal',
        imagePaths: ['/path/a.png', '/path/b.jpg'],
        documents: [
          DocumentAttachment(
            path: '/doc.pdf',
            fileName: 'doc.pdf',
            mime: 'application/pdf',
          ),
        ],
      );
      p.scheduleSave(data);
      await Future.delayed(const Duration(milliseconds: 900));
      final result = await p.restore();
      expect(result, isNotNull);
      expect(result!.text, 'multi modal');
      expect(result.imagePaths, ['/path/a.png', '/path/b.jpg']);
      expect(result.documents.length, 1);
      expect(result.documents[0].path, '/doc.pdf');
      expect(result.documents[0].fileName, 'doc.pdf');
      expect(result.documents[0].mime, 'application/pdf');
    });

    test(
      'empty content (no text, no media) is not saved and restore returns null',
      () async {
        final p = InputDraftPersistence();
        final data = ChatInputData(text: '');
        p.scheduleSave(data);
        await Future.delayed(const Duration(milliseconds: 900));
        final result = await p.restore();
        expect(result, isNull);
      },
    );

    test('delete removes saved draft', () async {
      final p = InputDraftPersistence();
      p.scheduleSave(ChatInputData(text: 'to delete'));
      await Future.delayed(const Duration(milliseconds: 900));
      await p.delete();
      final result = await p.restore();
      expect(result, isNull);
    });

    test('debounce: multiple scheduleSave only writes the last one', () async {
      final p = InputDraftPersistence();
      p.scheduleSave(ChatInputData(text: 'first'));
      await Future.delayed(const Duration(milliseconds: 100));
      p.scheduleSave(ChatInputData(text: 'second'));
      await Future.delayed(const Duration(milliseconds: 100));
      p.scheduleSave(ChatInputData(text: 'third'));
      await Future.delayed(const Duration(milliseconds: 900));
      final result = await p.restore();
      expect(result, isNotNull);
      expect(result!.text, 'third');
    });

    test('saveImmediately skips debounce delay', () async {
      final p = InputDraftPersistence();
      p.scheduleSave(ChatInputData(text: 'immediate'));
      await p.saveImmediately();
      final result = await p.restore();
      expect(result, isNotNull);
      expect(result!.text, 'immediate');
    });

    test('dispose with pending data does not throw', () async {
      final p = InputDraftPersistence();
      p.scheduleSave(ChatInputData(text: 'dispose test'));
      // no delay — pending is still active
      expect(() => p.dispose(), returnsNormally);
      // After dispose, further calls are no-ops
      expect(
        () => p.scheduleSave(ChatInputData(text: 'after dispose')),
        returnsNormally,
      );
      final result = await p.restore();
      // The pending write may or may not have completed; just ensure no crash
      expect(
        result,
        isNull,
      ); // nothing was flushed since dispose fires write async
    });

    test('dispose after flush saves pending data', () async {
      final p = InputDraftPersistence();
      p.scheduleSave(ChatInputData(text: 'flush before dispose'));
      await p.saveImmediately();
      p.dispose();
      final result = await p.restore();
      expect(result, isNotNull);
      expect(result!.text, 'flush before dispose');
    });

    test('restore with corrupted JSON returns null', () async {
      SharedPreferences.setMockInitialValues({
        'chat_draft_v1': 'this is not valid json',
      });
      final p = InputDraftPersistence();
      final result = await p.restore();
      expect(result, isNull);
    });

    test('restore with malformed structure returns null', () async {
      SharedPreferences.setMockInitialValues({
        'chat_draft_v1': '{"notText": 123}',
      });
      final p = InputDraftPersistence();
      final result = await p.restore();
      expect(result, isNull);
    });

    test('delete after dispose is no-op', () async {
      final p = InputDraftPersistence();
      p.dispose();
      await expectLater(p.delete(), completes);
    });

    test('saveImmediately after dispose is no-op', () async {
      final p = InputDraftPersistence();
      p.dispose();
      await expectLater(p.saveImmediately(), completes);
    });
  });
}
