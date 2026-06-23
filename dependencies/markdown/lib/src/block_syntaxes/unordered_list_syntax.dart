// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../block_parser.dart';
import '../patterns.dart';
import 'list_syntax.dart';

/// Parses unordered lists.
class UnorderedListSyntax extends ListSyntax {
  @override
  RegExp get pattern => listPattern;

  @override
  bool canParse(BlockParser parser) {
    // Check if it matches `hrPattern`, otherwise it will produce an infinite
    // loop if put `UnorderedListSyntax` or `UnorderedListWithCheckboxSyntax`
    // bofore `HorizontalRuleSyntax` and parse:
    // ```
    // * * *
    // ```
    if (hrPattern.hasMatch(parser.current.content)) {
      return false;
    }

    return pattern.hasMatch(parser.current.content);
  }

  const UnorderedListSyntax();
}
