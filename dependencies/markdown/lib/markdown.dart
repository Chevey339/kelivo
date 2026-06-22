// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Parses text in a Markdown-like format building an
/// [AST tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree)
/// that can then be rendered to HTML.
///
/// If you are only interested in rendering Markdown to HTML please refer
/// to the [README](../index.html) which explains the use of [markdownToHtml].
///
/// The main entrypoint to the library is the [Document] which
/// encapsulates the parsing process converting a Markdown text into
/// a tree of [Node] (`List<Node>`).
///
/// The two main parsing mechanics used are:
///
/// - Blocks, representing top-level elements
///   implemented via [BlockSyntax] subclasses,
///   such as headers, paragraphs, blockquotes, and code blocks.
/// - Inlines, representing chunks of text within a block with special meaning,
///   implemented via [InlineSyntax] subclasses,
///   such as links, emphasis, and inlined code.
///
/// Looking closely at [Document.new] a few other concepts merit a mention:
///
/// - [ExtensionSet] that provide configurations for common Markdown flavors
/// - [Resolver] which aid in resolving links and images
///
/// If you are looking at extending the library to support custom formatting
/// what you might want is to:
///
/// - Implement your own [InlineSyntax] subclasses
/// - Implement your own [BlockSyntax] subclasses
/// - Instruct the library to use those by:
///   - Creating a new [ExtensionSet] from one of the existing flavors
///     and adding your syntaxes.
///   - Passing your syntaxes to [Document] or [markdownToHtml] as parameters.
/// @docImport 'src/ast.dart';
/// @docImport 'src/block_syntaxes/block_syntax.dart';
/// @docImport 'src/document.dart';
/// @docImport 'src/extension_set.dart';
/// @docImport 'src/html_renderer.dart';
/// @docImport 'src/inline_syntaxes/inline_syntax.dart';
library;

import 'src/version.dart';

export 'src/ast.dart';
export 'src/block_parser.dart';
export 'src/block_syntaxes/alert_block_syntax.dart';
export 'src/block_syntaxes/block_syntax.dart';
export 'src/block_syntaxes/blockquote_syntax.dart';
export 'src/block_syntaxes/code_block_syntax.dart';
export 'src/block_syntaxes/dummy_block_syntax.dart';
export 'src/block_syntaxes/empty_block_syntax.dart';
export 'src/block_syntaxes/fenced_blockquote_syntax.dart';
export 'src/block_syntaxes/fenced_code_block_syntax.dart';
export 'src/block_syntaxes/footnote_def_syntax.dart';
export 'src/block_syntaxes/header_syntax.dart';
export 'src/block_syntaxes/header_with_id_syntax.dart';
export 'src/block_syntaxes/horizontal_rule_syntax.dart';
export 'src/block_syntaxes/html_block_syntax.dart';
export 'src/block_syntaxes/link_reference_definition_syntax.dart';
export 'src/block_syntaxes/list_syntax.dart';
export 'src/block_syntaxes/ordered_list_syntax.dart';
export 'src/block_syntaxes/ordered_list_with_checkbox_syntax.dart';
export 'src/block_syntaxes/paragraph_syntax.dart';
export 'src/block_syntaxes/setext_header_syntax.dart';
export 'src/block_syntaxes/setext_header_with_id_syntax.dart';
export 'src/block_syntaxes/table_syntax.dart';
export 'src/block_syntaxes/unordered_list_syntax.dart';
export 'src/block_syntaxes/unordered_list_with_checkbox_syntax.dart';
export 'src/document.dart';
export 'src/emojis.dart';
export 'src/extension_set.dart';
export 'src/html_renderer.dart';
export 'src/inline_parser.dart';
export 'src/inline_syntaxes/autolink_extension_syntax.dart';
export 'src/inline_syntaxes/autolink_syntax.dart';
export 'src/inline_syntaxes/code_syntax.dart';
export 'src/inline_syntaxes/color_swatch_syntax.dart';
export 'src/inline_syntaxes/decode_html_syntax.dart';
export 'src/inline_syntaxes/delimiter_syntax.dart';
export 'src/inline_syntaxes/email_autolink_syntax.dart';
export 'src/inline_syntaxes/emoji_syntax.dart';
export 'src/inline_syntaxes/emphasis_syntax.dart';
export 'src/inline_syntaxes/escape_html_syntax.dart';
export 'src/inline_syntaxes/escape_syntax.dart';
export 'src/inline_syntaxes/image_syntax.dart';
export 'src/inline_syntaxes/inline_html_syntax.dart';
export 'src/inline_syntaxes/inline_syntax.dart';
export 'src/inline_syntaxes/line_break_syntax.dart';
export 'src/inline_syntaxes/link_syntax.dart';
export 'src/inline_syntaxes/soft_line_break_syntax.dart';
export 'src/inline_syntaxes/strikethrough_syntax.dart';
export 'src/inline_syntaxes/text_syntax.dart';
export 'src/line.dart';

const version = packageVersion;
