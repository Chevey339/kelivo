import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/home/services/chat_suggestion_service.dart';

void main() {
  group('ChatSuggestionService.parseSuggestions', () {
    test('keeps up to three cleaned newline suggestions', () {
      final suggestions = ChatSuggestionService.parseSuggestions('''
1. 继续解释
- 给个例子
* 换种说法
4. 总结一下
''');

      expect(suggestions, ['继续解释', '给个例子', '换种说法']);
    });

    test(
      'drops empty and duplicate suggestions while keeping normal length',
      () {
        final suggestions = ChatSuggestionService.parseSuggestions('''

"继续"
继续
这是一个明显太长而不适合作为气泡的问题文本，不过现在应该还能保留
  - 下一步
''');

        expect(suggestions, ['继续', '这是一个明显太长而不适合作为气泡的问题文本，不过现在应该还能保留', '下一步']);
      },
    );

    test('keeps three natural long Chinese questions from model output', () {
      final suggestions = ChatSuggestionService.parseSuggestions('''
你觉得未来AI会取代人类的工作吗？比如程序员或医生这种职业。

如果AI真的变得很聪明，我们该怎么确保它不会做出有害的决定呢？

你提到多模态学习，现在有没有什么具体的应用例子让我感受一下？
''');

      expect(suggestions, [
        '你觉得未来AI会取代人类的工作吗？比如程序员或医生这种职业。',
        '如果AI真的变得很聪明，我们该怎么确保它不会做出有害的决定呢？',
        '你提到多模态学习，现在有没有什么具体的应用例子让我感受一下？',
      ]);
    });
  });
}
