// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:io/ansi.dart' as ansi;
import 'package:markdown/markdown.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/expected_output.dart';

/// Runs tests defined in "*.unit" files inside directory [name].
void testDirectory(String name, {ExtensionSet? extensionSet}) {
  for (final dataCase in dataCasesUnder(testDirectory: name)) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';

    final inlineSyntaxes = <InlineSyntax>[];
    final blockSyntaxes = <BlockSyntax>[];
    var enableTagfilter = false;

    if (dataCase.file.endsWith('_extension')) {
      final extension = dataCase.file.substring(
        0,
        dataCase.file.lastIndexOf('_extension'),
      );
      switch (extension) {
        case 'autolinks':
          inlineSyntaxes.add(AutolinkExtensionSyntax());
          break;
        case 'strikethrough':
          inlineSyntaxes.add(StrikethroughSyntax());
          break;
        case 'tables':
          blockSyntaxes.add(const TableSyntax());
          break;
        case 'disallowed_raw_html':
          enableTagfilter = true;
          break;
        default:
          throw UnimplementedError('Unimplemented extension "$extension"');
      }
    }

    validateCore(
      description,
      dataCase.input,
      dataCase.expectedOutput,
      extensionSet: extensionSet,
      inlineSyntaxes: inlineSyntaxes,
      blockSyntaxes: blockSyntaxes,
      enableTagfilter: enableTagfilter,
    );
  }
}

void testFile(
  String file, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
}) {
  for (final dataCase in dataCasesInFile(
    path: p.join(p.current, 'test', file),
  )) {
    final description =
        '${dataCase.directory}/${dataCase.file}.unit ${dataCase.description}';
    validateCore(
      description,
      dataCase.input,
      dataCase.expectedOutput,
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
    );
  }
}

void validateCore(
  String description,
  String markdown,
  String html, {
  Iterable<BlockSyntax> blockSyntaxes = const [],
  Iterable<InlineSyntax> inlineSyntaxes = const [],
  ExtensionSet? extensionSet,
  Resolver? linkResolver,
  Resolver? imageLinkResolver,
  bool inlineOnly = false,
  bool enableTagfilter = false,
}) {
  test(description, () {
    final result = markdownToHtml(
      markdown,
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
      extensionSet: extensionSet,
      linkResolver: linkResolver,
      imageLinkResolver: imageLinkResolver,
      inlineOnly: inlineOnly,
      enableTagfilter: enableTagfilter,
    );

    markdownPrintOnFailure(markdown, html, result);

    expect(result, html);
  });
}

String whitespaceColor(String input) => input
    .replaceAll(' ', ansi.lightBlue.wrap('·')!)
    .replaceAll('\t', ansi.backgroundDarkGray.wrap('\t')!);

void markdownPrintOnFailure(String markdown, String expected, String actual) {
  printOnFailure("""
INPUT:
'''r
${whitespaceColor(markdown)}'''
           
EXPECTED:
'''r
${whitespaceColor(expected)}'''

GOT:
'''r
${whitespaceColor(actual)}'''
""");
}
