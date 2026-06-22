// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../inline_parser.dart';
import '../util.dart';
import 'inline_syntax.dart';

/// Matches autolinks like `<foo@bar.example.com>`.
///
/// See <https://spec.commonmark.org/0.30/#email-address>.
class EmailAutolinkSyntax extends InlineSyntax {
  static const _email =
      r'''[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}'''
      r'''[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*''';

  EmailAutolinkSyntax() : super('<($_email)>', startCharacter: $lt);

  @override
  bool onMatch(InlineParser parser, Match match) {
    final url = match[1]!;
    final text = parser.encodeHtml ? escapeHtml(url) : url;
    final anchor = Element.text('a', text);
    anchor.attributes['href'] = Uri.encodeFull('mailto:$url');
    parser.addNode(anchor);

    return true;
  }
}
