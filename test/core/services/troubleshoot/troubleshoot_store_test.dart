import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/troubleshoot/troubleshoot_store.dart';
import 'package:Kelivo/core/services/troubleshoot/troubleshoot_data.dart';

void main() {
  setUp(() {
    TroubleshootStore.clear();
  });

  group('TroubleshootStore', () {
    test('set and get a result', () {
      final result = ErrorAnalysisResult(
        faqKey: 'test_key',
        titleKey: 'Test Title',
        summaryKey: 'Test Summary',
      );
      TroubleshootStore.set('msg1', result);
      expect(TroubleshootStore.get('msg1'), same(result));
    });

    test('get returns null for unknown message', () {
      expect(TroubleshootStore.get('nonexistent'), isNull);
    });

    test('remove removes the result', () {
      final result = ErrorAnalysisResult(
        faqKey: 'test_key',
        titleKey: 'Test Title',
        summaryKey: 'Test Summary',
      );
      TroubleshootStore.set('msg1', result);
      TroubleshootStore.remove('msg1');
      expect(TroubleshootStore.get('msg1'), isNull);
    });

    test('overwrite replaces existing result', () {
      final result1 = ErrorAnalysisResult(
        faqKey: 'key1',
        titleKey: 'Title1',
        summaryKey: 'Summary1',
      );
      final result2 = ErrorAnalysisResult(
        faqKey: 'key2',
        titleKey: 'Title2',
        summaryKey: 'Summary2',
      );
      TroubleshootStore.set('msg1', result1);
      TroubleshootStore.set('msg1', result2);
      expect(TroubleshootStore.get('msg1'), same(result2));
    });

    test('clear removes all results', () {
      TroubleshootStore.set(
        'msg1',
        ErrorAnalysisResult(faqKey: 'k1', titleKey: 't1', summaryKey: 's1'),
      );
      TroubleshootStore.set(
        'msg2',
        ErrorAnalysisResult(faqKey: 'k2', titleKey: 't2', summaryKey: 's2'),
      );
      TroubleshootStore.clear();
      expect(TroubleshootStore.get('msg1'), isNull);
      expect(TroubleshootStore.get('msg2'), isNull);
    });

    test('multiple messages are independent', () {
      final r1 = ErrorAnalysisResult(
        faqKey: 'k1',
        titleKey: 't1',
        summaryKey: 's1',
      );
      final r2 = ErrorAnalysisResult(
        faqKey: 'k2',
        titleKey: 't2',
        summaryKey: 's2',
      );
      TroubleshootStore.set('msg1', r1);
      TroubleshootStore.set('msg2', r2);
      expect(TroubleshootStore.get('msg1'), same(r1));
      expect(TroubleshootStore.get('msg2'), same(r2));
      TroubleshootStore.remove('msg1');
      expect(TroubleshootStore.get('msg1'), isNull);
      expect(TroubleshootStore.get('msg2'), same(r2));
    });
  });
}
