import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/image_context.dart';

ImageContextCandidate image(
  int i, {
  bool user = false,
  int bytes = 1,
  bool pinned = false,
}) => ImageContextCandidate(
  key: '$i',
  source: user ? ContextImageSource.user : ContextImageSource.tool,
  encodedBytes: bytes,
  protected: pinned,
);
Set<String> omitted(List<ImageContextCandidate> items, {int bytes = 100}) =>
    ImageContextPlanner.historyOmissions(
      items,
      maxBytes: bytes,
      maxSingleBytes: 100,
    );

void main() {
  test('recall preference survives JSON and pin changes independently', () {
    expect(const ImageContextSettings().allowRecall, isTrue);
    expect(ImageContextSettings.fromJson(const {}).allowRecall, isTrue);
    const settings = ImageContextSettings(allowRecall: false);
    final restored = ImageContextSettings.fromJson(settings.toJson());
    expect(restored.allowRecall, isFalse);
    expect(restored.automatic, isTrue);
    final pinned = restored.pin('message|part:1|0', true);
    expect(pinned.pinned, {'message|part:1|0'});
    expect(pinned.allowRecall, isFalse);
    expect(pinned.automatic, isTrue);
    final unpinned = pinned.pin('message|part:1|0', false);
    expect(unpinned.pinned, isEmpty);
    expect(unpinned.allowRecall, isFalse);
    expect(unpinned.automatic, isTrue);
    expect(
      ImageContextSettings.fromJson(
        const ImageContextSettings(automatic: false).toJson(),
      ).allowRecall,
      isTrue,
    );
  });

  test(
    'tool images retire in batches; user attachments have a separate lifetime',
    () {
      final history = [
        image(0, user: true),
        for (var i = 1; i <= 13; i++) image(i),
      ];
      expect(omitted(history.take(13).toList()), isEmpty);
      expect(omitted(history), {for (var i = 1; i <= 9; i++) '$i'});
      expect(omitted([...history, image(14)]), omitted(history));
    },
  );
  test(
    'byte evictions never resurrect after count eviction frees capacity',
    () {
      final history = [
        image(0, bytes: 60),
        for (var i = 1; i <= 45; i++) image(i, bytes: i % 7 + 1),
      ];
      var prior = <String>{};
      for (var n = 1; n <= history.length; n++) {
        final next = omitted(history.take(n).toList(), bytes: 64);
        expect(next.containsAll(prior), isTrue, reason: 'append $n');
        prior = next;
      }
      expect(
        omitted(history),
        omitted(List.of(history)),
        reason: 'restart replay',
      );
    },
  );
  test(
    'old tool observations leave before user images; pins stay at original position',
    () {
      final history = [
        image(0, user: true, bytes: 40),
        image(1, bytes: 40),
        image(2, bytes: 40),
      ];
      expect(omitted(history), {'1'});
      expect(
        omitted([
          image(0, pinned: true),
          for (var i = 1; i <= 13; i++) image(i),
        ]),
        isNot(contains('0')),
      );
    },
  );
  test(
    'a fresh tool observation can replace an older unpinned user attachment',
    () {
      expect(omitted([image(0, user: true, bytes: 60), image(1, bytes: 60)]), {
        '0',
      });
    },
  );

  test('a protected payload cannot bypass bytes or count limits', () {
    expect(
      () => ImageContextPlanner.validateBudget([
        image(1, bytes: 101, pinned: true),
      ], maxBytes: 100),
      throwsA(isA<ImageContextBudgetException>()),
    );
    expect(
      () => ImageContextPlanner.validateBudget([
        image(1, bytes: 101),
      ], maxBytes: 100),
      throwsA(isA<ImageContextBudgetException>()),
    );
  });
  test(
    'identity follows persisted message versions and remaps only retained messages',
    () {
      const a = ContextImageIdentity('version-a', 'part:1');
      const b = ContextImageIdentity('version-b', 'part:1');
      expect(a.handle, isNot(b.handle));
      final settings = ImageContextSettings(
        automatic: false,
        allowRecall: false,
        pinned: {a.key, b.key},
      );
      final mapped = settings.remap({'version-a': 'fork-a'});
      expect(mapped.pinned, {'fork-a|part:1|0'});
      expect(mapped.automatic, isFalse);
      expect(mapped.allowRecall, isFalse);
      expect(
        ImageContextSettings.fromJson(mapped.toJson()).pinned,
        mapped.pinned,
      );
    },
  );
}
