import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/home/controllers/file_processing_indicator_controller.dart';

void main() {
  const showDelay = Duration(milliseconds: 220);
  const minVisible = Duration(milliseconds: 320);

  FileProcessingIndicatorController newController() =>
      FileProcessingIndicatorController(
        showDelay: showDelay,
        minVisible: minVisible,
      );

  test('解析快于延迟时解析条根本不出现', () {
    fakeAsync((async) {
      final controller = newController();
      final seen = <String?>[];
      controller.messageId.addListener(
        () => seen.add(controller.messageId.value),
      );

      controller.start('a1');
      async.elapse(const Duration(milliseconds: 100));
      controller.finish('a1');
      async.elapse(const Duration(seconds: 1));

      expect(seen, isEmpty);
      expect(controller.messageId.value, isNull);
      controller.dispose();
    });
  });

  test('解析超过延迟后出现，并至少停留最短展示时间', () {
    fakeAsync((async) {
      final controller = newController();

      controller.start('a1');
      async.elapse(showDelay);
      expect(controller.messageId.value, 'a1');

      controller.finish('a1');
      // Still inside the hold: hiding now would be a flash.
      expect(controller.messageId.value, 'a1');

      async.elapse(minVisible);
      expect(controller.messageId.value, isNull);
      controller.dispose();
    });
  });

  test('展示时间已过后结束会立即隐藏', () {
    fakeAsync((async) {
      final controller = newController();

      controller.start('a1');
      async.elapse(showDelay + minVisible + const Duration(milliseconds: 10));
      expect(controller.messageId.value, 'a1');

      controller.finish('a1');
      expect(controller.messageId.value, isNull);
      controller.dispose();
    });
  });

  test('对话 A 结束不会取消对话 B 待显示的解析条', () {
    fakeAsync((async) {
      final controller = newController();

      // B raises the indicator while A is still generating.
      controller.start('b1');
      async.elapse(const Duration(milliseconds: 100));

      // A finishes in the background.
      controller.finish('a1');

      async.elapse(showDelay);
      expect(controller.messageId.value, 'b1', reason: 'A 的终止不应取消 B 的待显示计时器');
      controller.dispose();
    });
  });

  test('对话 A 结束不会隐藏对话 B 已显示的解析条', () {
    fakeAsync((async) {
      final controller = newController();

      controller.start('b1');
      async.elapse(showDelay + minVisible);
      expect(controller.messageId.value, 'b1');

      controller.finish('a1');
      async.elapse(const Duration(seconds: 1));

      expect(controller.messageId.value, 'b1');
      controller.dispose();
    });
  });

  test('新的解析立即从上一条手里接管', () {
    fakeAsync((async) {
      final controller = newController();

      controller.start('a1');
      async.elapse(showDelay);
      expect(controller.messageId.value, 'a1');

      controller.start('b1');
      expect(
        controller.messageId.value,
        isNull,
        reason: '旧的那条应立刻让出，而不是继续挂在上一条回复上',
      );

      async.elapse(showDelay);
      expect(controller.messageId.value, 'b1');
      controller.dispose();
    });
  });

  test('null 会清掉当前持有者，不管它是谁', () {
    fakeAsync((async) {
      final controller = newController();

      controller.start('a1');
      async.elapse(showDelay + minVisible);
      expect(controller.messageId.value, 'a1');

      // 传 null 的清理不做归属判断，任何持有者都会被清掉。
      controller.finish(null);
      expect(controller.messageId.value, isNull);
      controller.dispose();
    });
  });

  test('null 清理仍然遵守最短展示时间', () {
    fakeAsync((async) {
      final controller = newController();

      controller.start('a1');
      async.elapse(showDelay);
      controller.finish(null);
      expect(controller.messageId.value, 'a1');

      async.elapse(minVisible);
      expect(controller.messageId.value, isNull);
      controller.dispose();
    });
  });

  test('reset 忽略最短展示时间立刻清空', () {
    fakeAsync((async) {
      final controller = newController();

      controller.start('a1');
      async.elapse(showDelay);
      expect(controller.messageId.value, 'a1');

      controller.reset();
      expect(controller.messageId.value, isNull);
      expect(controller.owner, isNull);

      async.elapse(const Duration(seconds: 1));
      expect(controller.messageId.value, isNull);
      controller.dispose();
    });
  });
}
