import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/plan_mode_binding.dart';
import 'package:Kelivo/core/services/logging/context_log_models.dart';
import 'package:Kelivo/features/chat/widgets/proposed_plan_card.dart';

void main() {
  group('PlanModeBinding', () {
    test('defaults to disabled with null plan', () {
      const binding = PlanModeBinding();
      expect(binding.isPlanMode, isFalse);
      expect(binding.currentPlanMarkdown, isNull);

      final fromEmpty = PlanModeBinding.fromExtras({});
      expect(fromEmpty.isPlanMode, isFalse);
      expect(fromEmpty.currentPlanMarkdown, isNull);
    });

    test('reads and writes extras correctly', () {
      const binding = PlanModeBinding(
        isPlanMode: true,
        currentPlanMarkdown: '### Plan\n- Step 1',
      );
      final extras = binding.applyTo({'other.key': 'preserved'});

      expect(extras['other.key'], equals('preserved'));
      expect(extras[PlanModeBinding.keyEnabled], isTrue);
      expect(extras[PlanModeBinding.keyCurrentPlan], equals('### Plan\n- Step 1'));

      final restored = PlanModeBinding.fromExtras(extras);
      expect(restored.isPlanMode, isTrue);
      expect(restored.currentPlanMarkdown, equals('### Plan\n- Step 1'));
    });

    test('clearing plan mode removes keyEnabled and updates extras', () {
      final initial = const PlanModeBinding(
        isPlanMode: true,
        currentPlanMarkdown: 'Old plan',
      ).applyTo({});

      final disabled = PlanModeBinding.fromExtras(initial).copyWith(
        isPlanMode: false,
        clearPlan: true,
      );
      final updatedExtras = disabled.applyTo(initial);

      expect(updatedExtras.containsKey(PlanModeBinding.keyEnabled), isFalse);
      expect(updatedExtras.containsKey(PlanModeBinding.keyCurrentPlan), isFalse);
    });
  });

  group('ProposedPlanExtractor', () {
    test('extracts completed plan block and cleans enclosing text', () {
      const rawText = '''
Here is the exploration summary.

<proposed_plan>
# Proposed Plan
1. Edit file A
2. Test feature B
</proposed_plan>

Please review and confirm.
''';

      final result = ProposedPlanExtractor.extract(rawText);
      expect(result.hasPlan, isTrue);
      expect(result.planContent, equals('# Proposed Plan\n1. Edit file A\n2. Test feature B'));
      expect(result.cleanedText, contains('Here is the exploration summary.'));
      expect(result.cleanedText, contains('Please review and confirm.'));
      expect(result.cleanedText, isNot(contains('<proposed_plan>')));
      expect(result.cleanedText, isNot(contains('</proposed_plan>')));
    });

    test('handles streaming or incomplete plan block', () {
      const rawText = '''
Analyzing now...

<proposed_plan>
# Incomplete Plan
- Ongoing task...
''';

      final result = ProposedPlanExtractor.extract(rawText);
      expect(result.hasPlan, isTrue);
      expect(result.planContent, equals('# Incomplete Plan\n- Ongoing task...'));
      expect(result.cleanedText, equals('Analyzing now...'));
    });

    test('returns original text when no plan tag is present', () {
      const rawText = 'Just normal conversational text.';
      final result = ProposedPlanExtractor.extract(rawText);
      expect(result.hasPlan, isFalse);
      expect(result.planContent, isNull);
      expect(result.cleanedText, equals(rawText));
    });
  });

  group('ContextSource.planMode', () {
    test('is defined and can be serialized via wireName', () {
      expect(ContextSource.planMode.wireName, equals('planMode'));
      expect(ContextSourceWire.fromWire('planMode'), equals(ContextSource.planMode));
    });
  });

  group('PlanMode Tail Guard Contract', () {
    test('tail guard string contains required directives and tags', () {
      const directive =
          '[Active Mode: <collaboration_mode>plan</collaboration_mode>. System directive: You are operating in PLAN MODE. You are strictly forbidden from performing direct implementation or writing out complete executable code solutions directly. You must explore, clarify, or provide a structured, decision-complete plan enclosed in <proposed_plan>...</proposed_plan> tags.]';

      expect(directive, contains('<collaboration_mode>plan</collaboration_mode>'));
      expect(directive, contains('PLAN MODE'));
      expect(directive, contains('<proposed_plan>'));
      expect(directive, contains('decision-complete'));
    });
  });
}
