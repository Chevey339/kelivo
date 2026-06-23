// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:markdown/src/util.dart';
import 'package:test/test.dart';

void main() {
  group('String.toLines()', () {
    test('a single line without a line ending', () {
      const text = 'Foo';
      final lines = text.toLines();

      expect(lines.map((e) => e.toMap()), [
        {'content': 'Foo', 'isBlankLine': false},
      ]);
    });

    test('a single line with a line ending', () {
      const text = 'Foo\n';
      final lines = text.toLines();

      expect(lines.map((e) => e.toMap()), [
        {'content': 'Foo', 'isBlankLine': false},
      ]);
    });

    test('multiple lines with a blank line in between', () {
      const text = 'Foo\r\n\nBar';
      final lines = text.toLines();

      expect(lines.map((e) => e.toMap()), [
        {'content': 'Foo', 'isBlankLine': false},
        {'content': '', 'isBlankLine': true},
        {'content': 'Bar', 'isBlankLine': false},
      ]);
    });
  });

  group('String.indentation()', () {
    test('only spaces', () {
      expect('   '.indentation(), 3);
      expect('    '.indentation(), 4);
      expect('     '.indentation(), 5);
    });

    test('spaces and tabs', () {
      expect('\t  '.indentation(), 6);
      expect(' \t '.indentation(), 5);
      expect('  \t'.indentation(), 4);
      expect('\t\t  '.indentation(), 10);
      expect(' \t\t '.indentation(), 9);
      expect('  \t\t'.indentation(), 8);
    });

    test('spaces, tabs and non whitespace characters', () {
      expect('\t  foo'.indentation(), 6);
      expect(' \t foo'.indentation(), 5);
      expect('  \tfoo'.indentation(), 4);
    });
  });
}

extension on Line {
  Map<String, dynamic> toMap() => {
    'content': content,
    'isBlankLine': isBlankLine,
    if (tabRemaining != null) 'tabRemaining': tabRemaining,
  };
}
