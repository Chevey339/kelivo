import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_scroll_observer.dart';

void main() {
  Map<String, Object> event(
    int sequence,
    String phase, {
    bool supportsEnd = true,
    bool interacting = false,
    double gestureDelta = 0,
  }) => {
    'documentId': 'current',
    'sequence': sequence,
    'phase': phase,
    'offset': 25,
    'viewportExtent': 800,
    'contentExtent': 3000,
    'supportsScrollEnd': supportsEnd,
    'isUserInteracting': interacting,
    'gestureDelta': gestureDelta,
  };

  test('navigation invalidates a pending document handshake', () async {
    final identity = Completer<Object?>();
    final updates = <BrowserScrollState>[];
    final observer = BrowserScrollObserver(
      readDocumentId: () => identity.future,
      onUpdate: updates.add,
    );
    final pending = observer.handle([event(1, 'reset')]);
    observer.invalidate();
    identity.complete('current');
    expect(await pending, isFalse);
    expect(updates.single.phase, BrowserScrollPhase.reset);
    expect(await observer.handle([event(2, 'end')]), isFalse);
  });

  test(
    'old DOM cannot re-handshake during navigation before replacement',
    () async {
      final observer = BrowserScrollObserver(
        readDocumentId: () async => 'current',
        onUpdate: (_) {},
      );
      expect(await observer.handle([event(1, 'reset')]), isTrue);
      observer.invalidate();
      // The WebView still exposes the outgoing document while loading begins.
      expect(await observer.handle([event(2, 'reset')]), isFalse);
      expect(await observer.handle([event(3, 'end')]), isFalse);
      observer.allowCurrentDocument();
      expect(await observer.handle([event(4, 'reset')]), isTrue);
    },
  );

  test('unsupported scrollend is explicit and cannot produce an end', () async {
    final updates = <BrowserScrollState>[];
    final observer = BrowserScrollObserver(
      readDocumentId: () async => 'current',
      onUpdate: updates.add,
    );
    expect(
      await observer.handle([event(1, 'reset', supportsEnd: false)]),
      isTrue,
    );
    expect(
      await observer.handle([event(2, 'update', supportsEnd: false)]),
      isTrue,
    );
    expect(updates.last.supportsScrollEnd, isFalse);
    expect(
      await observer.handle([event(3, 'end', supportsEnd: false)]),
      isFalse,
    );
    expect(updates.last.phase, BrowserScrollPhase.update);
  });

  test(
    'malformed geometry and suspended document callbacks are rejected',
    () async {
      final observer = BrowserScrollObserver(
        readDocumentId: () async => 'current',
        onUpdate: (_) {},
      );
      expect(await observer.handle([event(1, 'reset')]), isTrue);
      expect(
        await observer.handle([
          {...event(2, 'update'), 'offset': double.nan},
        ]),
        isFalse,
      );
      expect(
        await observer.handle([
          {...event(3, 'update'), 'viewportExtent': 0},
        ]),
        isFalse,
      );
      expect(await observer.handle([event(4, 'suspend')]), isTrue);
      expect(await observer.handle([event(5, 'end')]), isFalse);
      expect(await observer.handle([event(6, 'reset')]), isTrue);
      observer.dispose();
      expect(await observer.handle([event(7, 'reset')]), isFalse);
    },
  );
  test(
    'touch intent is preserved independently of pinned scroll geometry',
    () async {
      final updates = <BrowserScrollState>[];
      final observer = BrowserScrollObserver(
        readDocumentId: () async => 'current',
        onUpdate: updates.add,
      );
      expect(await observer.handle([event(1, 'reset')]), isTrue);
      expect(
        await observer.handle([
          event(2, 'update', interacting: true, gestureDelta: 18),
        ]),
        isTrue,
      );
      expect(updates.last.isUserInteracting, isTrue);
      expect(updates.last.gestureDelta, 18);
      expect(updates.last.offset, 25);
      expect(await observer.handle([event(3, 'metrics')]), isTrue);
      expect(updates.last.isUserInteracting, isFalse);
      expect(await observer.handle([event(4, 'update')]), isTrue);
      expect(updates.last.isUserInteracting, isFalse);
      expect(updates.last.gestureDelta, 0);
      expect(
        await observer.handle([event(5, 'update', gestureDelta: 18)]),
        isFalse,
      );
      expect(
        await observer.handle([
          event(6, 'update', interacting: true, gestureDelta: double.nan),
        ]),
        isFalse,
      );
    },
  );
}
