import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/home/controllers/message_page_window.dart';

void main() {
  const controller = MessagePageWindowController(pageSize: 20, maxPages: 3);

  group('MessagePageWindowController', () {
    test('resetToLatest only keeps the last page on first load', () {
      expect(
        controller.resetToLatest(105),
        const MessagePageWindow(start: 85, end: 105),
      );
    });

    test('preloadOlder expands until three pages then slides upward', () {
      final first = controller.resetToLatest(100);
      final second = controller.preloadOlder(first, 100);
      final third = controller.preloadOlder(second, 100);
      final fourth = controller.preloadOlder(third, 100);

      expect(first, const MessagePageWindow(start: 80, end: 100));
      expect(second, const MessagePageWindow(start: 60, end: 100));
      expect(third, const MessagePageWindow(start: 40, end: 100));
      expect(fourth, const MessagePageWindow(start: 20, end: 80));
    });

    test('preloadNewer slides the window back toward the latest page', () {
      final current = const MessagePageWindow(start: 20, end: 80);
      expect(
        controller.preloadNewer(current, 100),
        const MessagePageWindow(start: 40, end: 100),
      );
    });

    test('sync keeps current window when user is not tracking latest', () {
      final current = const MessagePageWindow(start: 20, end: 80);
      expect(
        controller.sync(
          current: current,
          previousTotalItems: 100,
          nextTotalItems: 102,
          stickToLatest: false,
        ),
        const MessagePageWindow(start: 20, end: 80),
      );
    });

    test('sync keeps trailing window aligned to latest when requested', () {
      final current = const MessagePageWindow(start: 40, end: 100);
      expect(
        controller.sync(
          current: current,
          previousTotalItems: 100,
          nextTotalItems: 102,
          stickToLatest: true,
        ),
        const MessagePageWindow(start: 42, end: 102),
      );
    });

    test(
      'windowForIndex centers around target page within three-page budget',
      () {
        expect(
          controller.windowForIndex(totalItems: 100, targetIndex: 35),
          const MessagePageWindow(start: 0, end: 60),
        );
        expect(
          controller.windowForIndex(totalItems: 100, targetIndex: 95),
          const MessagePageWindow(start: 40, end: 100),
        );
      },
    );
  });
}
