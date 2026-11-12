import 'dart:async';
import 'package:Kelivo/features/chat/controllers/selection_translation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'language changes cancel only the old translation and ignore late chunks',
    () async {
      final streams = <String, StreamController<String>>{};
      final cancelled = <String>[];
      final controller = SelectionTranslationController(
        text: 'source',
        cancel: cancelled.add,
        request: (text, language, id) {
          expect(text, 'source');
          return (streams[language] = StreamController<String>()).stream;
        },
      );
      final first = controller.translate('English');
      streams['English']!.add('first');
      await Future<void>.delayed(Duration.zero);
      expect(controller.status, SelectionTranslationStatus.streaming);
      final second = controller.translate('Chinese');
      expect(cancelled, hasLength(1));
      expect(cancelled.single, startsWith('selection-translate-'));
      streams['English']!.add('stale');
      streams['Chinese']!.add('译文');
      await streams['English']!.close();
      await streams['Chinese']!.close();
      await Future.wait([first, second]);
      expect(controller.result, '译文');
      expect(controller.status, SelectionTranslationStatus.complete);
      controller.dispose();
    },
  );

  test(
    'failure can retry; disposing a streaming result cancels its request',
    () async {
      var calls = 0;
      final cancelled = <String>[];
      final pending = StreamController<String>();
      final controller = SelectionTranslationController(
        text: 'source',
        cancel: cancelled.add,
        request: (_, language, id) =>
            ++calls == 1 ? Stream.error(StateError('offline')) : pending.stream,
      );
      await controller.translate('English');
      expect(controller.status, SelectionTranslationStatus.failed);
      expect(controller.error, contains('offline'));
      final retry = controller.translate('English');
      expect(controller.status, SelectionTranslationStatus.loading);
      controller.dispose();
      expect(cancelled, hasLength(1));
      pending.add('late');
      await pending.close();
      await retry;
      expect(controller.result, isEmpty);
    },
  );
}
