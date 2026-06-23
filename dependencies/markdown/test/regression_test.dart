// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  test('HTML comment with dashes #2119', () {
    // See https://dartbug.com/tools/2119.
    // For this issue, the leading letter was needed,
    // an HTML comment starting a line is handled by a different path.
    // The empty line before the `-->` is needed.
    // The number of lines increase time exponentially.
    // The length of lines affect the base of the exponentiation.
    // Locally, three "Lorem-ipsum" lines ran in ~6 seconds, two in < 200 ms.
    // Adding a fourth line should ensure it cannot possibly finish in ten
    // seconds if the bug isn't fixed.
    const input = '''
a <!-- 
    - Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi
      ut aliquip ex ea commodo consequat.
    - Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi
      ut aliquip ex ea commodo consequat.
    - Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi
      ut aliquip ex ea commodo consequat.
    - Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi
      ut aliquip ex ea commodo consequat.
-->
''';

    final time = Stopwatch()..start();
    final html = markdownToHtml(input); // Should not hang.
    expect(html, isNotNull); // To use the output.
    final elapsed = time.elapsedMilliseconds;
    expect(elapsed, lessThan(10000));
  });

  test('HTML comment with lt/gt', () {
    // Incorrect parsing found as part of fixing #2119.
    // Now matches `<!--$text-->` where text
    // does not start with `>` or `->`, does not end with `-`,
    // and does not contain `--`.
    const input = 'a <!--<->>-<!-->';
    final html = markdownToHtml(input);
    expect(html, '<p>$input</p>\n');
  });
}
