// This package declares flutter_tools as an SDK dependency so the IDE and CLI
// use the same parser and package resolution as the installed Flutter SDK.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_tools/src/localizations/message_parser.dart';

Set<String> messageParameters(Node node) {
  final result = <String>{};
  if (const {
    ST.placeholderExpr,
    ST.pluralExpr,
    ST.selectExpr,
    ST.argumentExpr,
  }.contains(node.type)) {
    result.add(node.children[1].value!);
  }
  for (final child in node.children) {
    result.addAll(messageParameters(child));
  }
  return result;
}

void checkPluralBranches(Node node) {
  if (node.type == ST.pluralParts) {
    final seen = <String>{};
    for (final part in node.children) {
      final raw = part.children[0].type == ST.equalSign
          ? part.children[1].value!
          : part.children[0].value!;
      final branch = const {'0': 'zero', '1': 'one', '2': 'two'}[raw] ?? raw;
      if (!seen.add(branch)) {
        throw FormatException('Duplicate Flutter plural branch: $branch');
      }
    }
  }
  for (final child in node.children) {
    checkPluralBranches(child);
  }
}

Future<void> main() async {
  final input = jsonDecode(await stdin.transform(utf8.decoder).join()) as Map;
  final errors = <String, String>{};
  for (final entry in (input['messages'] as Map).entries) {
    final key = entry.key as String;
    final pair = entry.value as Map;
    try {
      final source = Parser(key, 'en', pair['source'] as String).parse();
      final target = Parser(key, 'target', pair['target'] as String).parse();
      final expected = messageParameters(source);
      final actual = messageParameters(target);
      if (expected.length != actual.length || !expected.containsAll(actual)) {
        throw FormatException('Expected placeholders $expected, got $actual');
      }
      checkPluralBranches(target);
    } catch (error) {
      errors[key] = error.toString();
    }
  }
  stdout.writeln(jsonEncode(errors));
  if (errors.isNotEmpty) exitCode = 1;
}
