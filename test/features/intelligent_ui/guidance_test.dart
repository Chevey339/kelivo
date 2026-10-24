import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/skills/skill_frontmatter.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_guidance.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';

UiSurfaceController controller(String name, String source) {
  final result = UiSurfaceController(
    owner: UiSurfaceOwner(revisionId: 'example', surfaceKey: name),
  );
  result.updateSource(
    source,
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  return result;
}

void main() {
  test(
    'committed Skill assets exactly match the final catalog and templates',
    () {
      final assets = UiGuidance.generateAssets();
      expect(UiGuidance.generateAssets(), assets);
      final root = Directory('assets/skills/visualize');
      final files = root
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.substring(root.path.length + 1))
          .toSet();
      expect(files, assets.keys.toSet());
      for (final entry in assets.entries) {
        expect(
          File('${root.path}/${entry.key}').readAsStringSync(),
          entry.value,
          reason: entry.key,
        );
      }
      expect(SkillFrontmatter.parse(assets['SKILL.md']!).validate(), isEmpty);
      for (final entry in assets.entries) {
        for (final match in RegExp(
          r'`(references/[a-z-]+\.md)`',
        ).allMatches(entry.value)) {
          expect(assets, contains(match.group(1)), reason: entry.key);
        }
      }
    },
  );

  test('all components and functions have generated signatures and guidance', () {
    expect(UiGuidance.uses.keys.toSet(), UiCatalog.components.keys.toSet());
    expect(
      UiGuidance.functionUses.keys.toSet(),
      UiCatalog.functions.keys.toSet(),
    );
    final grouped = UiGuidance.groups.values.expand((v) => v).toList();
    expect(grouped.toSet(), UiCatalog.components.keys.toSet());
    expect(grouped.length, grouped.toSet().length);
    for (final group in UiGuidance.groups.keys) {
      final reference = UiGuidance.componentReference(group);
      for (final name in UiGuidance.groups[group]!) {
        final spec = UiCatalog.components[name]!;
        expect(reference, contains('`${spec.name}('));
        expect(
          UiGuidance.semantics,
          contains(
            '${spec.name}: policy=${spec.textPolicy.name}; fields=${spec.semanticFields.join(', ')}.',
          ),
        );
      }
    }
  });

  test(
    'guidance byte guards supplement separately measured tokenizer budgets',
    () {
      expect(
        utf8.encode(UiGuidance.capabilitySummary).length,
        lessThanOrEqualTo(1536),
      );
      expect(utf8.encode(UiGuidance.main).length, lessThanOrEqualTo(3600));
      final relevant = [
        ...UiGuidance.groups.keys.map(UiGuidance.componentReference),
        UiGuidance.functions,
        UiGuidance.fewShots,
      ].join('\n');
      expect(utf8.encode(relevant).length, lessThanOrEqualTo(16000));
    },
  );

  for (final example in UiGuidance.examples.entries) {
    test(
      'complete ${example.key} example parses, resolves and has no invalid nodes',
      () {
        final c = controller(example.key, example.value);
        addTearDown(c.dispose);
        expect(c.phase, SurfacePhase.complete);
        expect(c.parsed.program.diagnostics, isEmpty);
        expect(c.nodes.values.every((node) => node.valid), isTrue);
        expect(c.nodes['root'], isNotNull);
      },
    );
  }
  test('calculator and curve examples actually respond to their controls', () {
    final calculator = controller(
      'calculator',
      UiGuidance.examples['calculator']!,
    );
    addTearDown(calculator.dispose);
    expect(calculator.nodes['result']!.properties['value'], 36);
    expect(
      calculator.setInputs({'quantity': 5}, token: calculator.token),
      UiMutationResult.accepted,
    );
    expect(calculator.nodes['result']!.properties['value'], 60);
    final curve = controller('curve', UiGuidance.examples['curve']!);
    addTearDown(curve.dispose);
    expect(
      curve.setInputs({'slope': 3}, token: curve.token),
      UiMutationResult.accepted,
    );
    final points = curve.nodes['chart']!.properties['data'] as List;
    expect(points.first, {'x': -2.0, 'y': -5.0});
    expect(points.last, {'x': 2.0, 'y': 7.0});
    expect(curve.nodes['table']!.properties['data'], points);
  });
  test(
    'conditional example hides the field and prepares current Ask context',
    () {
      final c = controller(
        'conditional-form',
        UiGuidance.examples['conditional-form']!,
      );
      addTearDown(c.dispose);
      expect(c.nodes['offsetInput']!.visible, isTrue);
      expect(c.nodes['result']!.properties['value'], 11);
      expect(
        c.setInputs({'useOffset': false}, token: c.token),
        UiMutationResult.accepted,
      );
      expect(c.nodes['offsetInput']!.visible, isFalse);
      expect(c.nodes['result']!.properties['value'], 10);
      expect(c.nodes['ask']!.askContext, {
        'useOffset': false,
        'offset': 1.0,
        'result': 10.0,
      });
    },
  );
}
