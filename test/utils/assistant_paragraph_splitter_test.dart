import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/chat/utils/assistant_paragraph_splitter.dart';

void main() {
  test('splits on blank lines', () {
    expect(splitAssistantParagraphs('one\n\ntwo\n\nthree'), [
      'one',
      'two',
      'three',
    ]);
  });

  test('keeps single-newline text in one bubble', () {
    expect(splitAssistantParagraphs('one\ntwo'), ['one\ntwo']);
  });

  test('returns text unchanged when there is nothing to split', () {
    expect(splitAssistantParagraphs('  hi  '), ['  hi  ']);
    expect(splitAssistantParagraphs(''), ['']);
  });

  test('keeps blank lines inside fenced code blocks', () {
    const text = 'intro\n\n```dart\nvoid a() {}\n\nvoid b() {}\n```\n\nend';
    expect(splitAssistantParagraphs(text), [
      'intro',
      '```dart\nvoid a() {}\n\nvoid b() {}\n```',
      'end',
    ]);
  });

  test('leaves an unterminated streaming fence intact', () {
    const text = 'intro\n\n```dart\nvoid a() {}\n\nvoid b';
    expect(splitAssistantParagraphs(text), [
      'intro',
      '```dart\nvoid a() {}\n\nvoid b',
    ]);
  });

  test('keeps blank lines inside display math', () {
    const text = 'before\n\n\$\$\na = b\n\nc = d\n\$\$\n\nafter';
    expect(splitAssistantParagraphs(text), [
      'before',
      '\$\$\na = b\n\nc = d\n\$\$',
      'after',
    ]);
  });

  test('keeps a loose ordered list in one bubble', () {
    const text = 'Steps:\n\n1. first\n\n2. second\n\n3. third';
    expect(splitAssistantParagraphs(text), [
      'Steps:',
      '1. first\n\n2. second\n\n3. third',
    ]);
  });

  test('keeps a heading with the paragraph it introduces', () {
    expect(splitAssistantParagraphs('## Title\n\nbody\n\ntail'), [
      '## Title\n\nbody',
      'tail',
    ]);
  });

  test('keeps indented continuations attached', () {
    const text = 'code:\n\n    line a\n\n    line b\n\nend';
    expect(splitAssistantParagraphs(text), [
      'code:\n\n    line a\n\n    line b',
      'end',
    ]);
  });

  test('collapses runs of blank lines', () {
    expect(splitAssistantParagraphs('a\n\n\n\nb'), ['a', 'b']);
  });

  test('keeps blank lines inside bracket display math', () {
    const text = 'before\n\n\\[\na = b\n\nc = d\n\\]\n\nafter';
    expect(splitAssistantParagraphs(text), [
      'before',
      '\\[\na = b\n\nc = d\n\\]',
      'after',
    ]);
  });

  test('keeps a details block whole', () {
    const text =
        'intro\n\n<details>\n<summary>more</summary>\n\nbody one\n\nbody two\n'
        '</details>\n\nend';
    expect(splitAssistantParagraphs(text), [
      'intro',
      '<details>\n<summary>more</summary>\n\nbody one\n\nbody two\n</details>',
      'end',
    ]);
  });

  test('does not treat an info-string line inside a fence as a closer', () {
    const text = 'intro\n\n```\n```not-a-close\n\nstill code\n```\n\nend';
    expect(splitAssistantParagraphs(text), [
      'intro',
      '```\n```not-a-close\n\nstill code\n```',
      'end',
    ]);
  });

  test('closes a fence only on a matching marker of at least equal length', () {
    const text = 'intro\n\n````\n```\n\ninner\n````\n\nend';
    expect(splitAssistantParagraphs(text), [
      'intro',
      '````\n```\n\ninner\n````',
      'end',
    ]);
  });
}
