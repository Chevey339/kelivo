// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Matches autolinks like `<http://foo.com>`.
class AutolinkSyntax extends InlineSyntax {
  AutolinkSyntax() : super(r'<(([a-zA-Z][a-zA-Z\-\+\.]+):(?://)?[^\s>]*)>');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final url = match[1]!;
    final text = parser.encodeHtml ? escapeHtml(url) : url;
    final anchor = Element.text('a', text);

    final destination = normalizeLinkDestination(url);
    anchor.attributes['href'] = parser.encodeHtml
        ? escapeHtml(destination)
        : destination;
    parser.addNode(anchor);

    return true;
  }
}
