// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast.dart';
import '../charcode.dart';
import '../util.dart';
import 'link_syntax.dart';

/// Matches images like `![alternate text](url "optional title")` and
/// `![alternate text][label]`.
class ImageSyntax extends LinkSyntax {
  ImageSyntax({super.linkResolver})
    : super(pattern: r'!\[', startCharacter: $exclamation);

  @override
  Element createNode(
    String destination,
    String? title, {
    required List<Node> Function() getChildren,
  }) {
    final element = Element.empty('img');
    final children = getChildren();
    element.attributes['src'] = normalizeLinkDestination(
      escapePunctuation(destination),
    );
    element.attributes['alt'] = children.map((node) {
      // See https://spec.commonmark.org/0.30/#image-description.
      // An image description may contain links. Fetch text from the alt
      // attribute if this nested link is an image.
      if (node is Element && node.tag == 'img') {
        return node.attributes['alt'];
      }
      return node.textContent;
    }).join();
    if (title != null && title.isNotEmpty) {
      element.attributes['title'] = normalizeLinkTitle(title);
    }
    return element;
  }
}
