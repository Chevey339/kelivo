## 7.3.1

* Preserve metadata passed to fenced code blocks as
  `data-metadata` on the created `pre` element.
* Update the README link to the markdown playground
  (https://dart-lang.github.io/tools).
* Update `package:web` API references in the example.
* Fix performance and correctness of HTML comment parser.
* Optimize indentation processing of fenced code blocks.
* Fix an issue with nested list structure when indented by tabs (#2172).
* Deprecated `LinkContext` and `BlockParser.standardBlockSyntaxes`.
  Implementation members that should never have been made public.
* Require Dart `^3.9.0`.

## 7.3.0

* Move to `dart-lang/tools` monorepo.
* Fix an issue with checkbox list items separated with blank lines (#602).
* Require package `web: '>=0.4.2 <2.0.0'`.
* Fix several `RangeError` hazards in links (#623).
* Export `LinkReferenceDefinitionSyntax` publicly (#626).

## 7.2.2

* Fix a crash parsing alert block syntax (#584).
* Have alert block syntax support multiple paragraphs (#577).
* Require Dart `^3.2.0`.

## 7.2.1

* Address a termination issue with GitHub alert syntax parsing.

## 7.2.0

* Require Dart `^3.1.0`.
* Update all CommonMark specification links to 0.30.
* Fix beginning of line detection in `AutolinkExtensionSyntax`.
* Add a new syntax `AlertBlockSyntax` to parse GitHub Alerts.

## 7.1.1

* Fix delimiter row matching pattern for tables.
* Tables are now able to interrupt other blocks.
* Fix an obscure issue with HtmlBlockSyntax.

## 7.1.0

* Support for [footnotes](https://pandoc.org/MANUAL.html#footnotes).
* Fixed bug causing infinite loop for links inside tables.

## 7.0.2

* Require Dart 2.19
* Fix an issue in `HeaderWithIdSyntax`, do not generate heading IDs for headings
  with no content.

## 7.0.1

* Remove RegExp lookarounds from autolink extension patterns. (Fixes issues when
  running on Safari.)

## 7.0.0

* **Breaking change**: `close()` of `DelimiterSyntax` and `LinkSyntax`
  returns multiple nodes instead of single one.
* **Breaking change**: Remove deprecated APIs, including `TagSyntax`,
  `indicatorForCheckedCheckBox`, and `indicatorForUncheckedCheckBox`.
* **Breaking change**: Removed `BlockHtmlSyntax`, `BlockTagBlockHtmlSyntax`,
  `LongBlockHtmlSyntax`, and `OtherTagBlockHtmlSyntax`.
* **Breaking change**: Change the `line` properties of type `String` to `Line`.
* **Breaking change**: Change the `lines` properties of type `List<String>` to
  `List<Line>`.
* Add a new syntax `HtmlBlockSyntax` to parse HTML blocks.
* Add an `enableTagfilter` option to `HtmlRenderer` to eanble GFM `tagfilter`
  extension.
* Add a new syntax `DecodeHtmlSyntax` to decode HTML entity and numeric
  character references.
* Add a new syntax `SoftLineBreakSyntax` to remove the single space before the
  line ending.
* Add a new syntax `EscapeHtmlSyntax` to encode (`"`), (`<`), (`>`) and (`&`).
* Add an option `caseSensitive` to `TextSyntax`.
* Add a new public method `parse(String text)` for `Document`.
* Add a new public method `parseLineList(List<Line> text)` for `Document`.
* Add a new type: `Line`.
* Add a new optional parameter `parentSyntax` for `parseLines()` of
  `BlockParser`, which can be used when parsing nested blocks.
* Add a new optional parameter `disabledSetextHeading` for `parseLines()` of
  `BlockParser`, which is used to disable the `SetextHeaderSyntax`.
* Add a new public property `previousSyntax` for `BlockParser`.

## 6.0.1

* Fix a crash in checkbox lists when mixing checkbox items with
  non-checkbox items.

## 6.0.0

* Require Dart 2.17
* Add support to GFM extension for GitHub task lists (aka checkboxes).  These
  are only active in the `gitHubFlavored` and `gitHubWeb` extension sets.
* Add support for `#ff0000` color swatches.
* Change emoji list do be derived from the GitHub API. The only two emoji that
  visually change are `:cricket:` and `:beetle:`. There are alternate emoji
  `:cricket_game:` and `:lady_beetle:` which can be used to access the previous
  emoji.  `update_github_emoji.dart` now pulls all emoji info directly from
  GitHub API and as a result we have now support the entire GitHub emoji set
  (excluding the 19 custom GitHub specific emoji which have no Unicode support).
* **Breaking change**: The `TagSyntax` is _deprecated_.
* Add new syntax `DelimiterSyntax`.
* **Breaking change**: `StrikethroughSyntax` now extends `DelimiterSyntax`
  instead of `TagSyntax`.
* **Breaking change**: `LinkSyntax` now extends `DelimiterSyntax`
  instead of `TagSyntax`.
* Add two new emphasis syntaxes `EmphasisSyntax.underscore` and 
  `EmphasisSyntax.asterisk`.

## 5.0.0

* Breaking change: Change the type of `parseInline`'s parameter from `String?`
  to `String`.
* Fix table-rendering bug when table rows have trailing whitespace.
  [#368](https://github.com/dart-lang/markdown/issues/368).
* Do not allow reference link labels to contain left brackets. Thanks
  @chenzhiguang.
  [#335](https://github.com/dart-lang/markdown/issues/335).
* Treat lines matching a code block syntax as continuations of paragraphs,
  inside blockquotes. Thanks @chenzhiguang.
  [#358](https://github.com/dart-lang/markdown/issues/358).
* Add a syntax for GitLab-flavored fenced blockquotes. GitLab-flavored Markdown
  will be evaluated into an ExtensionSet, in a future release. Thanks
  @chenzhiguang.
  [#359](https://github.com/dart-lang/markdown/issues/359).
* Add `bool withDefaultInlineSyntaxes` and `bool withDefaultBlockSyntaxes`
  parameters to `markdownToHtml` and `Document` to support the case of
  specifying exactly the list of desired syntaxes. Thanks @chenzhiguang.
  [#393](https://github.com/dart-lang/markdown/issues/393).

## 4.0.1

* Export `src/emojis.dart` in public API.
* Update version of example page.
* Internal: enforce lint rules found in the lints package.
* Bump io dependency to `^1.0.0`.

## 4.0.0

* Stable null safety release.
* Require the latest `args`, update the markdown executable to be opted in.

## 4.0.0-nullsafety.0

* Migrate package to Dart's null safety language feature, requiring Dart
  2.12 or higher.
* **Breaking change:** The TagSyntax constructor no longer takes an `end`
  parameter. TagSyntax no longer implements `onMatchEnd`. Instead, TagSyntax
  implements a method called `close` which creates and returns a Node, if a
  Node can be created and closed at the current position. If the TagSyntax
  instance cannot create a Node at the current position, the method should
  return `null`. Some TagSyntax subclasses will unconditionally create a tag in
  `close`, while others may be unable to, such as LinkSyntax, if an inline or
  reference link could not be resolved.
* Improved parsing of nested links, images, and emphasis. CommonMark compliance
  of emphasis-parsing improves to 99%, and link-parsing compliance rises to
  93%. Overall compliance improves to 94% and overall GitHub-flavored Markdown
  improves to 93%.

## 3.0.0

* **Breaking change:** Remove `ListSyntax.removeLeadingEmptyLine`,
  `ListSyntax.removeTrailingEmptyLines`, `TableSyntax.parseAlignments`,
  `TableSyntax.parseRow`.
* Allow intra-word strikethrough in GFM
  ([#300](https://github.com/dart-lang/markdown/issues/300)).
* **Breaking change:** Change `BlockSyntax.canEndBlock` from a getter to a
  method accepting a BlockParser.

## 2.1.8

* Deprecate the _public_ methods `ListSyntax.removeLeadingEmptyLine`,
  `ListSyntax.removeTrailingEmptyLines`, `TableSyntax.parseAlignments`,
  `TableSyntax.parseRow`. These will be made private in a major version bump as
  early as 3.0.0.

## 2.1.7

* Add dependency on the meta package

## 2.1.6

* Fix for custom link resolvers
  ([#295](https://github.com/dart-lang/markdown/issues/295)).
* Add missing HTML 5 block-level items
  ([#294](https://github.com/dart-lang/markdown/pull/294)).

## 2.1.5

* Overhaul table row parsing. This does not have many consequences, except that
  whitespace around escaped pipes is handled better.
  ([#287](https://github.com/dart-lang/markdown/issues/287)).

## 2.1.4

* Correctly parse a reference link with a newline in the link reference part
  ([#281](https://github.com/dart-lang/markdown/issues/281)).

## 2.1.3

* Do not encode HTML in link URLs. Also do not encode HTML in link text when
  `encodeHtml` is false (e.g. when used in Flutter).

## 2.1.2

* Drop support for Dart 2.0.0 through 2.1.0.
* Recognize Unicode ellipsis (…) and other Unicode punctuation as punctuation
  when parsing potential emphasis.
* Reduce time to parse a large HTML-block-free Markdown document (such as that
  in #271) by more than half.
* Add a new optional parameter for InlineSyntax(), `startCharacter`, where a
  subclass can specify a single character to try to match, before matching with
  more expensive regular expressions.

## 2.1.1

* Fix for encoding HTML for text string that contains `<pre>`
  ([#263](https://github.com/dart-lang/markdown/issues/263)).

## 2.1.0

* Improve strict spec compliance of `>` handling by always encoding as `&gt;`
  – unless preceded by `/`.
* Improve strict spec compliance for `blockquote` by always putting the closing
  tag on a new line.
* Improve strict spec compliance for `code` elements defined with "\`".
* Properly encode `<`, `>`, and `"` as their respective HTML entities when
  interpreted as text.
* Improve inline code parsing when using multiple backticks.
* Do not encode HTML in indented code blocks when `encodeHtml` is false (e.g.
  when used in Flutter).

## 2.0.3

* Render element attributes in the order they were defined.
  Aligns more closely with the strict spec definition.
* Correctly render `&` within inline image titles.
* Add 68 new GitHub emoji.
* Escape HTML attribute for fenced code blocks, in the info string.

## 2.0.2

* Set max SDK version to `<3.0.0`, and adjust other dependencies.

## 2.0.1

* Require Dart 2.0.0-dev.

## 2.0.0

* **Breaking change:** The `Link` class has been renamed `LinkReference`, and
  the `Document` field, `refLinks`, has been renamed `linkReferences`.
* **Breaking change:** Remove the deprecated `ExtensionSet.gitHub` field.
  Use `ExtensionSet.gitHubFlavored` instead.
* **Breaking change:** Make all of the fields on `Document` read-only.
* Overhaul support for emphasis (`*foo*` and `_foo_`) and strong emphasis
  (`**foo**` and `__foo__`), dramatically improving CommonMark compliance.
* Overhaul support for links and images, again dramatically improving CommonMark
  compliance.
* Improve support for tab characters, and horizontal rules.
* Add support for GitHub Flavored Markdown's Strikethrough extension. See the
  [GFM spec][strikethrough].
* The above fixes raise compliance with the CommonMark specs to 93%, and
  compliance with the GFM specs to 92%.
* Add an `encodeHtml` parameter to `Document`, which defaults to true. When
  false, HTML entities (such as `&copy;` and the `<` character) will not be
  escaped, useful when rendering Markdown in some output format other than HTML.
* Allow the binary script to take a `--extension-set` option.

  A reminder: You can [run `bin/markdown.dart` from anywhere][pub-global] via:

  ```shell
  $ pub global activate markdown
  $ markdown
  ```

[strikethrough]: https://github.github.com/gfm/#strikethrough-extension-
[pub-global]: https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path

## 1.1.1

* Add support for GitHub's colon-based Emoji syntax. :tada:! This is available
  in the `gitHubWeb` extension set.

## 1.1.0

* Make the constructor for ExtensionSet public, for tools like dartdoc.
* Split the `gitHub` ExtensionSet into two sets: `gitHubFlavored`, which
  represents the GitHub Flavored Markdown spec, and `gitHubWeb`, which
  represents what GitHub actually renders Markdown.

## 1.0.0

* Fix issue where `accept` could cause an exception.
* Remove deprecated `escapeHtml` function.
* Fix compliance with auto-links, including support for email addresses.
* Updated `ExtensionSet.gitHub` to more closely align with GitHub markdown.

## 0.11.4

* Fix bug with lazy blockquote continuations (#162)
* Fix bug with list item continuations (#156)

## 0.11.3

* Deprecate `escapeHtml`. This code exists in `dart:convert`.

## 0.11.2

* Fix reference code links inside blockquotes.
* Add src/util.dart to exports.

## 0.11.1

* Add version information:
  * `dart bin/markdown.dart --version` now shows the package version number.
  * The playground app now shows the version number.
* Improve autolink parsing.
* Add new table syntax: `TableSyntax`.
* Add new ExtensionSet that includes the table syntax: `ExtensionSet.gitHub`.
* For development: added `tool/travis.sh`.
* Support multiline Setext headers.
* Handle loose-vs-strict list items better.
* Support ordered lists that start with a number other than 1.

## 0.11.0+1

* Add playground app at https://dart-lang.github.io/markdown.

## 0.11.0

* Parse HTML blocks more accurately, according to
  [CommonMark](https://spec.commonmark.org/0.24/#html-blocks).
* Support [shortcut reference
  links](https://spec.commonmark.org/0.24/#reference-link).
* Don't allow an indented code block to interrupt a paragraph.
* Change definition of "loose" and "strict" lists (items wrapped in
  paragraph tags vs not) to CommonMark's. The primary difference is that any
  single list item can trigger the entire list to be marked as "loose", rather
  than defining "looseness" on each specific item.
* Fix paragraph continuations in blockquotes and list items.
* Fix silly typing bug with `tool/common_mark_stats.dart`, which resulted in
  a dramatic overestimate of our CommonMark compliance.
* There are now 427/613 (69%) passing CommonMark v0.25 specs.

## 0.10.1

* Parse [hard line breaks](https://spec.commonmark.org/0.24/#hard-line-breaks)
  properly (#86). Thanks @mehaase!
* Fix processing of `[ ... ]` syntax when no resolver is specified (#92).
* There are now 401/613 (65%) passing CommonMark v0.24 specs.
  (_Actually: after 0f64c8f the actual number of passing tests was 352/613
  (57%)._)

## 0.10.0

* BREAKING: Now following the CommonMark spec for fenced code blocks.
  If a language (info string) is provided, it is added as a class to the `code`
  element with a `language-` prefix.
* BREAKING: Now following the CommonMark spec for images. Previously,
  `![text](img.png)` would compile too
  `<a href="img.prg"><img src="img.prg" alt="text"></img></a>`. That same code
  will now compile to `<img src="img.png" alt="text" />`.
* Fix all [strong mode][] errors.

[strong mode]: https://github.com/dart-lang/dev_compiler/blob/master/STRONG_MODE.md

## 0.9.0

* BREAKING: The text `[foo] (bar)` no longer renders as an inline link (#53).
* BREAKING: Change list parsing to allow lists to begin immediately after a
  preceding block element, without a blank line in between.
* Formalize an API for Markdown extensions (#43).
* Introduce ExtensionSets. FencedCodeBlock is considered an extension, but
  existing usage of `markdownToHtml()` and `new Document()` will use the
  default extension set, which is `ExtensionSet.commonMark`, which includes
  FencedCodeBlock.
* Inline HTML syntax support; This is also considered an extension (#18).
* The text `[foo]()` now renders as an inline link.
* Whitespace now allowed between a link's destination and title (#65).
* Header identifier support in the HeaderWithIdSyntax and
  SetextHeaderWithIdSyntax extensions.
* Implement backslash-escaping so that Markdown syntax can be escaped, such as
  `[foo]\(bar) ==> <p>[foo](bar)</p>`.
* Support for hard line breaks with either `\\\n` or <code>  \n</code> (#30,
  #60).
* New public method for BlockParser: `peek(int linesAhead)`, meant for use in
  subclasses.
* New public members for ListSyntax: `blocksInList` and `determineBlockItems()`,
  meant for use in subclasses.
* Improve public docs (better, and more of them).

## 0.8.0

* **Breaking:** Remove (probably unused) fields: `LinkSyntax.resolved`,
  `InlineParser.currentSource`.
* Switch tests to use [test][] instead of [unittest][].
* Fix a few bugs in inline code syntax.
* Ignore underscores inside words (#41).

[test]: https://pub.dev/packages/test
[unittest]: https://pub.dev/packages/unittest

## 0.7.2

* Allow resolving links that contain inline syntax (#42).

## 0.7.1+3

* Updated homepage.

## 0.7.1+2

* Formatted code.

* Updated readme.
