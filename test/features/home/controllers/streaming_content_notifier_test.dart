import 'package:Kelivo/features/home/controllers/streaming_content_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamingContentNotifier', () {
    test('用户滚动冻结期间缓存最新内容但不通知监听者', () {
      final notifier = StreamingContentNotifier();
      addTearDown(notifier.dispose);

      final valueListenable = notifier.getNotifier('assistant-1');
      final observed = <StreamingContentData>[];
      valueListenable.addListener(() {
        observed.add(valueListenable.value);
      });

      notifier.updateContent('assistant-1', '已显示内容', 1);
      expect(observed, hasLength(1));
      expect(valueListenable.value.content, '已显示内容');

      notifier.setUpdatesFrozen(true);
      notifier.updateContent('assistant-1', '滚动期间第一段新增内容', 2);
      notifier.updateContent('assistant-1', '滚动期间最后一段新增内容', 3);

      expect(observed, hasLength(1));
      expect(valueListenable.value.content, '已显示内容');
      expect(notifier.hasPendingFrozenUpdate('assistant-1'), isTrue);

      final flushed = notifier.setUpdatesFrozen(false);

      expect(flushed, isTrue);
      expect(observed, hasLength(2));
      expect(valueListenable.value.content, '滚动期间最后一段新增内容');
      expect(valueListenable.value.totalTokens, 3);
      expect(notifier.hasPendingFrozenUpdate('assistant-1'), isFalse);
    });

    test('冻结期间合并内容、推理和工具状态，恢复时只通知一次', () {
      final notifier = StreamingContentNotifier();
      addTearDown(notifier.dispose);

      final valueListenable = notifier.getNotifier('assistant-1');
      var notifyCount = 0;
      valueListenable.addListener(() {
        notifyCount++;
      });

      notifier.setUpdatesFrozen(true);
      notifier.updateContent('assistant-1', '正文', 5);
      notifier.updateReasoning(
        'assistant-1',
        reasoningText: '推理',
        contentSplitOffsets: const <int>[0],
      );
      notifier.notifyToolPartsUpdated(
        'assistant-1',
        toolCountAtSplit: const <int>[1],
      );

      expect(notifyCount, 0);

      final flushed = notifier.setUpdatesFrozen(false);

      expect(flushed, isTrue);
      expect(notifyCount, 1);
      expect(valueListenable.value.content, '正文');
      expect(valueListenable.value.totalTokens, 5);
      expect(valueListenable.value.reasoningText, '推理');
      expect(valueListenable.value.contentSplitOffsets, const <int>[0]);
      expect(valueListenable.value.toolCountAtSplit, const <int>[1]);
      expect(valueListenable.value.toolPartsVersion, 1);
    });

    test('冻结期间移除 notifier 会延迟到最新内容 flush 之后', () {
      final notifier = StreamingContentNotifier();
      addTearDown(notifier.dispose);

      final valueListenable = notifier.getNotifier('assistant-1');
      var notifyCount = 0;
      valueListenable.addListener(() {
        notifyCount++;
      });

      notifier.updateContent('assistant-1', '旧内容', 1);
      notifier.setUpdatesFrozen(true);
      notifier.updateContent('assistant-1', '最终内容', 2);
      notifier.removeNotifier('assistant-1');

      expect(notifier.hasNotifier('assistant-1'), isTrue);
      expect(valueListenable.value.content, '旧内容');

      final flushed = notifier.setUpdatesFrozen(false);

      expect(flushed, isTrue);
      expect(notifyCount, 2);
      expect(valueListenable.value.content, '最终内容');
      expect(notifier.hasNotifier('assistant-1'), isFalse);
    });
  });
}
