import 'package:Kelivo/utils/protected_text.dart';
import 'package:Kelivo/utils/source_text_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  test(
    'generated separators do not move a selected source range backwards',
    () {
      final map = SourceTextMap.fromSegments(const [
        TextSegment(text: 'first', sourceSpan: SourceSpan(4, 9)),
        TextSegment(text: '\n', sourceSpan: SourceSpan(0, 0)),
        TextSegment(text: 'next', sourceSpan: SourceSpan(13, 17)),
      ]);
      final range = map.sourceRange(1, 6);
      expect((range.start, range.end), (5, 9));
    },
  );
  test(
    'repeated display transforms retain source ranges near the end of long text',
    () {
      final raw = '${'ab ' * 5000}end!';
      final output = ProtectedText(
        raw,
        const [],
        sourceMap: SourceTextMap.identity(raw.length),
      ).replaceAll('a', 'AA').replaceAll('b', '');
      final range = output.sourceMap!.sourceRange(
        output.text.length - 4,
        output.text.length,
      );
      expect((range.start, range.end), (raw.length - 4, raw.length));
    },
  );
  test(
    'visual deletion preserves selected word and reverse highlight coordinates',
    () {
      const raw = 'PREFIX keep DELETE target';
      final output = ProtectedText(
        raw,
        const [],
        sourceMap: SourceTextMap.identity(raw.length),
      ).replaceAll(RegExp('PREFIX[ ]|DELETE[ ]'), '');
      expect(output.text, 'keep target');
      final range = output.sourceMap!.sourceRange(5, 11);
      expect((range.start, range.end), (19, 25));
      final inverse = output.sourceMap!.displayRanges(range).single;
      expect((inverse.start, inverse.end), (5, 11));
    },
  );

  test(
    'replacement characters retain the matched source while the suffix stays linear',
    () {
      const raw = 'a x tail';
      final output = ProtectedText(
        raw,
        const [],
        sourceMap: SourceTextMap.identity(raw.length),
      ).replaceAll('x', 'expanded');
      final changed = output.sourceMap!.sourceRange(3, 6);
      expect((changed.start, changed.end), (2, 3));
      final tail = output.sourceMap!.sourceRange(11, 15);
      expect((tail.start, tail.end), (4, 8));
      final highlight = output.sourceMap!
          .displayRanges(const SourceSpan(2, 3))
          .single;
      expect((highlight.start, highlight.end), (2, 10));
    },
  );

  test(
    'paragraph slices and hidden gaps retain distinct original occurrences',
    () {
      final joined = SourceTextMap.join([
        SourceTextMap.identity(9),
        SourceTextMap.identity(9, offset: 30),
      ]);
      final second = joined.slice(9, 18).sourceRange(0, 9);
      expect((second.start, second.end), (30, 39));
      final spanning = joined.sourceRange(7, 11);
      expect((spanning.start, spanning.end), (7, 32));
    },
  );

  test(
    'unchanged replacements and an empty trimmed document keep valid boundaries',
    () {
      final output = ProtectedText(
        'abcdef',
        const [],
        sourceMap: SourceTextMap.identity(6),
      ).replaceAll('abc', 'abc');
      final range = output.sourceMap!.sourceRange(1, 2);
      expect((range.start, range.end), (1, 2));
      final empty = SourceTextMap.identity(4).slice(4, 4).sourceRange(0, 0);
      expect((empty.start, empty.end), (4, 4));
    },
  );
}
