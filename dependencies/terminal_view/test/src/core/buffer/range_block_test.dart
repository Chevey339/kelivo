import 'package:test/test.dart';
import 'package:terminal_view/terminal_view.dart';

void main() {
  group('BufferLineRange', () {
    test('toSegments() works', () {
      final range = BufferRangeBlock(CellOffset(10, 10), CellOffset(12, 12));
      final segments = range.toSegments().toList();

      expect(segments, hasLength(3));

      expect(segments[0].start, equals(10));
      expect(segments[0].end, equals(12));

      expect(segments[1].start, equals(10));
      expect(segments[1].end, equals(12));

      expect(segments[2].start, equals(10));
      expect(segments[2].end, 12);
    });

    test('toSegments() works with reversed range', () {
      final range = BufferRangeBlock(CellOffset(12, 12), CellOffset(10, 10));
      final segments = range.toSegments().toList();

      expect(segments, hasLength(3));

      expect(segments[0].start, equals(10));
      expect(segments[0].end, equals(12));

      expect(segments[1].start, equals(10));
      expect(segments[1].end, equals(12));

      expect(segments[2].start, equals(10));
      expect(segments[2].end, 12);
    });

    test('contains() works', () {
      final range = BufferRangeBlock(CellOffset(10, 10), CellOffset(10, 12));

      expect(range.contains(CellOffset(10, 10)), isTrue);
      expect(range.contains(CellOffset(10, 11)), isTrue);
      expect(range.contains(CellOffset(10, 12)), isTrue);

      expect(range.contains(CellOffset(10, 9)), isFalse);
      expect(range.contains(CellOffset(10, 13)), isFalse);
    });

    test('contains() works with reversed range', () {
      final range = BufferRangeBlock(CellOffset(10, 12), CellOffset(10, 10));

      expect(range.contains(CellOffset(10, 10)), isTrue);
      expect(range.contains(CellOffset(10, 11)), isTrue);
      expect(range.contains(CellOffset(10, 12)), isTrue);

      expect(range.contains(CellOffset(10, 9)), isFalse);
      expect(range.contains(CellOffset(10, 13)), isFalse);
    });

    test('merge() works', () {
      final range1 = BufferRangeBlock(CellOffset(10, 10), CellOffset(10, 12));
      final range2 = BufferRangeBlock(CellOffset(10, 13), CellOffset(10, 15));

      final merged = range1.merge(range2);

      expect(merged.begin, equals(CellOffset(10, 10)));
      expect(merged.end, equals(CellOffset(10, 15)));
    });

    test('merge() works with reversed range', () {
      final range1 = BufferRangeBlock(CellOffset(10, 12), CellOffset(10, 10));
      final range2 = BufferRangeBlock(CellOffset(10, 13), CellOffset(10, 15));

      final merged = range1.merge(range2);

      expect(merged.begin, equals(CellOffset(10, 10)));
      expect(merged.end, equals(CellOffset(10, 15)));
    });

    test('extend() works', () {
      final range = BufferRangeBlock(CellOffset(10, 10), CellOffset(10, 12));

      final extended = range.extend(CellOffset(10, 13));

      expect(extended.begin, equals(CellOffset(10, 10)));
      expect(extended.end, equals(CellOffset(10, 13)));
    });

    test('extend() works with reversed range', () {
      final range = BufferRangeBlock(CellOffset(10, 12), CellOffset(10, 10));

      final extended = range.extend(CellOffset(10, 13));

      expect(extended.begin, equals(CellOffset(10, 10)));
      expect(extended.end, equals(CellOffset(10, 13)));
    });

    test('extend() works with reversed range and reversed extend', () {
      final range = BufferRangeBlock(CellOffset(10, 12), CellOffset(10, 10));

      final extended = range.extend(CellOffset(10, 9));

      expect(extended.begin, equals(CellOffset(10, 9)));
      expect(extended.end, equals(CellOffset(10, 12)));
    });
  });
}
