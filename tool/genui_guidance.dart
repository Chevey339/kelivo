import 'dart:io';
import 'dart:convert';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_guidance.dart';

/// Offline deterministic asset generation; never invokes a model or network.
void main(List<String> args) {
  if (args.isNotEmpty &&
      !(args.length == 1 &&
          const ['--check', '--budget-input'].contains(args.single))) {
    stderr.writeln(
      'Usage: dart run tool/genui_guidance.dart [--check|--budget-input]',
    );
    exitCode = 64;
    return;
  }
  if (args.contains('--budget-input')) {
    stdout.writeln(
      jsonEncode({
        'summary': UiGuidance.capabilitySummary,
        'skill': UiGuidance.main,
        'referencesWithExamples': [
          ...UiGuidance.groups.keys.map(UiGuidance.componentReference),
          UiGuidance.functions,
          UiGuidance.fewShots,
        ].join('\n'),
      }),
    );
    return;
  }
  final check = args.isNotEmpty;
  final assets = UiGuidance.generateAssets();
  for (final entry in assets.entries) {
    final file = File('assets/skills/visualize/${entry.key}');
    if (check) {
      if (!file.existsSync() || file.readAsStringSync() != entry.value) {
        stderr.writeln('Generated guidance differs: ${file.path}');
        exitCode = 1;
      }
    } else {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
    }
  }
  stdout.writeln(
    '${assets.length} generated guidance assets ${check ? 'checked' : 'written'}.',
  );
}
