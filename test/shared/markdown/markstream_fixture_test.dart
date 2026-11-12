import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/markdown/markstream_documents.dart';

void main() {
  for (final fixture in [
    (
      markstreamAppendFixture,
      30000,
      'df682bd51858d978af771c20d7e9ea9135f37ecb07631c79f55d3a307f4c3af6',
    ),
    (
      markstreamColdFixture,
      100000,
      'a771fabe572bc0e331ee88cf4800c20c6e3143cfd7e35471d28316c8e180a035',
    ),
  ]) {
    test(
      'fixed ${fixture.$2}-character performance corpus stays identical',
      () {
        expect(fixture.$1.length, fixture.$2);
        expect(sha256.convert(utf8.encode(fixture.$1)).toString(), fixture.$3);
        expect(
          RegExp(r'^```dart$', multiLine: true).allMatches(fixture.$1).length,
          5,
        );
        expect(
          RegExp(r'^```$', multiLine: true).allMatches(fixture.$1).length,
          5,
        );
        expect(
          RegExp(
            r'^\| --- \| --- \|$',
            multiLine: true,
          ).allMatches(fixture.$1).length,
          2,
        );
      },
    );
  }
}
