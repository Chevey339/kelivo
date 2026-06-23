// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

import 'blns.dart';

// The BLNS tests merely test that `markdownToHtml` does not throw or hang while
// processing "naughty string" inputs. While there are examples of multi-byte
// characters, non-visible characters, etc., these tests should not be _relied
// upon_ for testing multi-byte character support, etc.
void main() {
  test('parsing blns', () {
    // This is more a test of update_blns.dart: we're testing that the strings
    // were encoded half-decently, and nothing got globbed up into a big
    // multiline string.
    expect(blns, hasLength(515));
  });

  var index = 0;
  for (final str in blns) {
    test('blns string $index', () {
      final result = markdownToHtml(str);
      expect(result, const TypeMatcher<String>());
    });
    index++;
  }

  index = 0;
  for (final str in blns) {
    test('blns string $index w/ gitHubWeb', () {
      final result = markdownToHtml(str, extensionSet: ExtensionSet.gitHubWeb);
      expect(result, const TypeMatcher<String>());
    });
    index++;
  }
}
