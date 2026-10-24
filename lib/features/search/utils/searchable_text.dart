/// Ordinary message metadata must not enter global-search results. Apply this
/// before inserting literal UI projection text, never to the completed mix.
String stripHiddenSearchBlocks(String source) => source
    .replaceAll(_geminiThoughtSignature, ' ')
    .replaceAll(_thinking, ' ')
    .replaceAll(_reasoning, ' ');

final _geminiThoughtSignature = RegExp(
  r'<!--\s*gemini_thought_signatures:.*?-->',
  dotAll: true,
);
final _thinking = RegExp(
  r'<(?:think|thought)>[\s\S]*?<\/(?:think|thought)>',
  caseSensitive: false,
);
final _reasoning = RegExp(
  r'<reasoning>[\s\S]*?<\/reasoning>',
  caseSensitive: false,
);
