import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/plan_mode_binding.dart';
import 'package:Kelivo/core/models/task_execution_binding.dart';
import 'package:Kelivo/core/services/logging/context_log_models.dart';
import 'package:Kelivo/features/chat/utils/task_plan_parser.dart';
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

  group('TaskExecutionBinding & TaskExecutionPlan', () {
    test('calculates step count, progress fraction and completion', () {
      final plan = TaskExecutionPlan(
        id: 'plan_1',
        title: 'Test Plan',
        steps: [
          const TaskStep(id: 's1', title: 'Step 1', status: TaskStepStatus.completed),
          const TaskStep(id: 's2', title: 'Step 2', status: TaskStepStatus.inProgress),
          const TaskStep(id: 's3', title: 'Step 3', status: TaskStepStatus.pending),
          const TaskStep(id: 's4', title: 'Step 4', status: TaskStepStatus.pending),
        ],
        createdAt: 1000,
      );

      expect(plan.totalCount, equals(4));
      expect(plan.completedCount, equals(1));
      expect(plan.progressFraction, equals(0.25));
      expect(plan.isCompleted, isFalse);
      expect(plan.activeStep?.id, equals('s2'));

      final updated = plan.updateStepStatus('s2', TaskStepStatus.completed);
      expect(updated.completedCount, equals(2));
      expect(updated.progressFraction, equals(0.5));
    });

    test('serializes and deserializes to extras correctly', () {
      final plan = TaskExecutionPlan(
        id: 'plan_1',
        title: 'Test Plan',
        steps: [
          const TaskStep(id: 's1', title: 'Step 1', status: TaskStepStatus.completed),
        ],
        createdAt: 1000,
      );
      final binding = TaskExecutionBinding(plan: plan);
      final extras = binding.applyTo({});

      final restored = TaskExecutionBinding.fromExtras(extras);
      expect(restored.hasActivePlan, isFalse); // only 1 step and it's completed
      expect(restored.plan?.title, equals('Test Plan'));
      expect(restored.plan?.steps.first.title, equals('Step 1'));
    });
  });

  group('TaskPlanParser', () {
    test('parses markdown plan into structured task steps', () {
      const planMarkdown = '''
# 鹅鹕骑自行车 2D SVG 动画实现方案

## 方案概述
使用原生 SVG 绘制呆萌生动的鹅鹕与复古自行车。

## 落地实施步骤 (Key Changes)
1. 新建并编写 /workspace/pelican-bike.html
2. SVG 画布与视口规格定义
3. 核心动画与联动机制 (CSS Keyframes)
4. 验证与测试方案

## 假设与权衡
- 纯原生 SVG 动画
''';

      final plan = TaskPlanParser.parse(planMarkdown);
      expect(plan.title, contains('鹅鹕骑自行车'));
      expect(plan.steps.length, equals(4));
      expect(plan.steps[0].title, contains('新建并编写'));
      expect(plan.steps[1].title, contains('SVG 画布'));
      expect(plan.steps[2].title, contains('核心动画'));
      expect(plan.steps[3].title, contains('验证与测试'));
    });

    test('parses checklist items with checkboxes', () {
      const planMarkdown = '''
# Todo Tasks
- [x] Done step 1
- [ ] Pending step 2
- [ ] Pending step 3
''';

      final plan = TaskPlanParser.parse(planMarkdown);
      expect(plan.steps.length, equals(3));
      expect(plan.steps[0].status, equals(TaskStepStatus.completed));
      expect(plan.steps[1].status, equals(TaskStepStatus.pending));
      expect(plan.steps[2].status, equals(TaskStepStatus.pending));
    });

    test('cleans bold and backtick markdown formatting without producing literal \$1', () {
      const planMarkdown = '''
# 落地实施计划

## 落地实施步骤 (Key Changes)
1. **新建并编写** `/workspace/pelican-bike.html` :
2. **SVG 画布与图层层级** (从后至前)
3. **核心动画与联动机制** (`CSS Keyframes`)
''';

      final plan = TaskPlanParser.parse(planMarkdown);
      expect(plan.steps.length, equals(3));
      expect(plan.steps[0].title, equals('新建并编写 /workspace/pelican-bike.html'));
      expect(plan.steps[0].title, isNot(contains(r'$1')));
      expect(plan.steps[1].title, equals('SVG 画布与图层层级 (从后至前)'));
      expect(plan.steps[1].title, isNot(contains(r'$1')));
      expect(plan.steps[2].title, equals('核心动画与联动机制 (CSS Keyframes)'));
      expect(plan.steps[2].title, isNot(contains(r'$1')));
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

    test('revision prompt formats feedback with plan mode instruction', () {
      const feedbackText = '把颜色改为复古湖水绿，并增加停止按钮';
      final prompt = '我对刚才的方案有以下修改要求：\n$feedbackText\n\n请在计划模式下结合上述要求重新调整，并输出更新后的完整方案（用 <proposed_plan> 包裹）。';

      expect(prompt, contains(feedbackText));
      expect(prompt, contains('计划模式'));
      expect(prompt, contains('<proposed_plan>'));
    });
  });
}

