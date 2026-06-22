// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The line contains only whitespace or is empty.
final emptyPattern = RegExp(r'^(?:[ \t]*)$');

/// A series of `=` or `-` (on the next line) define setext-style headers.
final setextPattern = RegExp(r'^[ ]{0,3}(=+|-+)\s*$');

/// Leading (and trailing) `#` define atx-style headers.
///
/// Starts with 1-6 unescaped `#` characters which must not be followed by a
/// non-space character. Line may end with any number of `#` characters,.
final headerPattern = RegExp(
  r'^ {0,3}(#{1,6})(?:[ \x09\x0b\x0c].*?)?(?:\s(#*)\s*)?$',
);

/// The line starts with `>` with one optional space after.
final blockquotePattern = RegExp(r'^[ ]{0,3}>[ \t]?.*$');

/// A line indented four spaces. Used for code blocks and lists.
final indentPattern = RegExp(r'^(?:    | {0,3}\t)(.*)$');

/// Fenced code block.
final codeFencePattern = RegExp(
  '^([ ]{0,3})(?:(?<backtick>`{3,})(?<backtickInfo>[^`]*)|'
  r'(?<tilde>~{3,})(?<tildeInfo>.*))$',
);

/// Fenced blockquotes.
final blockquoteFencePattern = RegExp(r'^>{3}\s*$');

/// Three or more hyphens, asterisks or underscores by themselves. Note that
/// a line like `----` is valid as both HR and SETEXT. In case of a tie,
/// SETEXT should win.
final hrPattern = RegExp(r'^ {0,3}([-*_])[ \t]*\1[ \t]*\1(?:\1|[ \t])*$');

/// **Unordered list**
/// A line starting with one of these markers: `-`, `*`, `+`. May have up to
/// three leading spaces before the marker and any number of spaces or tabs
/// after.
///
/// **Ordered list**
///
/// A line starting with a number like `123.`. May have up to three leading
/// spaces before the marker and any number of spaces or tabs after.
final listPattern = RegExp(
  r'^[ ]{0,3}(?:(\d{1,9})[\.)]|[*+-])(?:[ \t]+(.*))?$',
);

/// A line of hyphens separated by at least one pipe.
final tablePattern = RegExp(
  r'^[ ]{0,3}\|?([ \t]*:?\-+:?[ \t]*\|[ \t]*)+([ \t]|[ \t]*:?\-+:?[ \t]*)?$',
);

/// A line starting with `[^` and contains with `]:`, but without special chars
/// (`\] \r\n\x00\t`) between. Same as [GFM](cmark-gfm/src/scanners.re:318).
final footnotePattern = RegExp(r'(^[ ]{0,3})\[\^([^\] \r\n\x00\t]+)\]:[ \t]*');

/// A pattern which should never be used. It just satisfies non-nullability of
/// pattern fields.
final dummyPattern = RegExp('');

/// A [String] pattern to match a named tag like `<table>` or `</table>`.
const namedTagDefinition =
    // Opening tag begins.
    '<'
    // Tag name.
    '[a-zA-Z][a-zA-Z0-9-]*'
    // Attribute begins, see
    // https://spec.commonmark.org/0.30/#attribute.
    r'(?:\s+'
    // Attribute name, see
    // https://spec.commonmark.org/0.30/#attribute-name.
    '[a-zA-Z_:][a-zA-Z0-9._:-]*'
    //
    '(?:'
    // Attribute value specification, see
    // https://spec.commonmark.org/0.30/#attribute-value-specification.
    r'\s*=\s*'
    // Attribute value, see
    // https://spec.commonmark.org/0.30/#unquoted-attribute-value.
    r'''(?:[^\s"'=<>`]+?|'[^']*?'|"[^"]*?")'''
    // Attribute ends.
    ')?)*'
    // Opening tag ends.
    r'\s*/?>'
    // Or
    '|'
    // Closing tag, see
    // https://spec.commonmark.org/0.30/#closing-tag.
    r'</[a-zA-Z][a-zA-Z0-9-]*\s*>';

/// A pattern to match the start of an HTML block.
///
/// The 7 conditions here correspond to the 7 start conditions in the Commonmark
/// specification one by one: https://spec.commonmark.org/0.30/#html-block.
final htmlBlockPattern = RegExp(
  '^ {0,3}(?:'
  '<(?<condition_1>pre|script|style|textarea)'
  r'(?:\s|>|$)'
  '|'
  '(?<condition_2><!--)'
  '|'
  r'(?<condition_3><\?)'
  '|'
  '(?<condition_4><![a-z])'
  '|'
  r'(?<condition_5><!\[CDATA\[)'
  '|'
  '</?(?<condition_6>address|article|aside|base|basefont|blockquote|body|'
  'caption|center|col|colgroup|dd|details|dialog|dir|DIV|dl|dt|fieldset|'
  'figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|'
  'header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|'
  'optgroup|option|p|param|section|source|summary|table|tbody|td|tfoot|th|'
  'thead|title|tr|track|ul)'
  r'(?:\s|>|/>|$)'
  '|'
  // Here we are more restrictive than the Commonmark definition (Rule #7).
  // Otherwise some raw HTML test cases will fail, for example:
  // https://spec.commonmark.org/0.30/#example-618.
  // Because if a line is treated as an HTML block, it will output as a
  // Text node directly, and the RawHtmlSyntax will not have a chance to
  // validate if this HTML tag is legal or not.
  '(?<condition_7>(?:$namedTagDefinition)\\s*\$))',
  caseSensitive: false,
);

/// ASCII punctuation characters.
// See https://spec.commonmark.org/0.30/#unicode-whitespace-character.
const asciiPunctuationCharacters = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';

/// ASCII punctuation characters with some characters escaped, in order to be
// used in the RegExp character set.
const asciiPunctuationEscaped = r'''!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~''';

/// A pattern to match HTML entity references and numeric character references.
// https://spec.commonmark.org/0.30/#entity-and-numeric-character-references
final htmlCharactersPattern = RegExp(
  '&(?:([a-z0-9]+)|#([0-9]{1,7})|#x([a-f0-9]{1,6}));',
  caseSensitive: false,
);

/// A line starts with `[`.
final linkReferenceDefinitionPattern = RegExp(r'^[ ]{0,3}\[');

/// Alert type patterns.
///
/// A alert block is similar to a blockquote, starts with `> [!TYPE]`, and only
/// 5 types are supported (case-insensitive).
final alertPattern = RegExp(
  r'^\s{0,3}>\s{0,3}\\?\[!(note|tip|important|caution|warning)\\?\]\s*$',
  caseSensitive: false,
);
