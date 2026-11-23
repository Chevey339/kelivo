import 'package:diffutil_dart/diffutil.dart';
import 'package:flutter/foundation.dart';

import '../../models/model_spec.dart';
import '../../providers/settings_provider.dart';
import '../api/chat_api_service.dart';

typedef CreationPromptSpan = ({String text, bool added});

abstract final class CreationPromptEnhancer {
  static Future<String> rewrite({
    required ProviderConfig provider,
    required ModelSpec model,
    required String original,
    required String template,
    required List<String> references,
    required String requestId,
    bool again = false,
  }) async {
    final prompt = template.contains('{prompt}')
        ? template.replaceAll('{prompt}', original)
        : '$template\n\n$original';
    final result = await ChatApiService.generateMessage(
      config: provider,
      modelId: model.id,
      messages: [
        {
          'role': 'user',
          'content': again
              ? '$prompt\n\nTry a distinct rewrite of the same request.'
              : prompt,
        },
      ],
      userImagePaths: model.supportsImageInput ? references : null,
      requestId: requestId,
      parseMarkdownImageLinks: false,
      builtInToolMode: BuiltInToolMode.none,
      requestTimeout: const Duration(seconds: 60),
    );
    return result.text.trim();
  }

  static Future<List<CreationPromptSpan>> diff(
    String original,
    String rewrite,
  ) => compute(_diff, (original, rewrite));
}

List<CreationPromptSpan> _diff((String, String) text) {
  // Compare words and individual CJK characters so punctuation and spacing
  // remain exactly as returned by the model.
  final tokens = RegExp(
    r'[\u3000-\u9fff\uac00-\ud7af]|[a-zA-Z0-9_]+|\s+|.',
    unicode: true,
  );
  List<String> tokenize(String input) => [
    for (final match in tokens.allMatches(input)) match.group(0)!,
  ];
  final original = tokenize(text.$1);
  final rewrite = tokenize(text.$2);
  if (original.length + rewrite.length > 8000) {
    return [(text: text.$2, added: true)];
  }
  final changes = calculateListDiff(original, rewrite, detectMoves: false);
  final tokensWithStyle = [
    for (final value in original) (text: value, added: false),
  ];
  for (final change in changes.getUpdatesWithData()) {
    switch (change) {
      case DataInsert(:final position, :final data):
        tokensWithStyle.insert(position, (text: data, added: true));
      case DataRemove(:final position):
        tokensWithStyle.removeAt(position);
      case DataChange() || DataMove():
        return [(text: text.$2, added: true)];
    }
  }
  final spans = <CreationPromptSpan>[];
  var added = false;
  var buffer = StringBuffer();
  for (final token in tokensWithStyle) {
    if (token.added != added) {
      if (buffer.isNotEmpty) spans.add((text: buffer.toString(), added: added));
      buffer = StringBuffer();
      added = token.added;
    }
    buffer.write(token.text);
  }
  if (buffer.isNotEmpty) spans.add((text: buffer.toString(), added: added));
  return spans;
}
