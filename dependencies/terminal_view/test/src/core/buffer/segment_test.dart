import 'package:test/test.dart';
import 'package:terminal_view/terminal_view.dart';

void main() {
  group('BufferSegment', () {
    test('isWithin() works', () {
      final segments = BufferRangeLine(CellOffset(10, 10), CellOffset(10, 12))
          .toSegments()
          .toList();

      expect(segments[0].start, equals(10));
      expect(segments[0].end, null);
      expect(segments[0].isWithin(CellOffset(10, 10)), isTrue);
      expect(segments[0].isWithin(CellOffset(11, 10)), isTrue);
      expect(segments[0].isWithin(CellOffset(100, 10)), isTrue);
      expect(segments[0].isWithin(CellOffset(9, 10)), isFalse);

      expect(segments[1].start, null);
      expect(segments[1].end, null);
      expect(segments[1].isWithin(CellOffset(10, 11)), isTrue);
      expect(segments[1].isWithin(CellOffset(11, 11)), isTrue);
      expect(segments[1].isWithin(CellOffset(100, 11)), isTrue);
      expect(segments[1].isWithin(CellOffset(0, 11)), isTrue);

      expect(segments[2].start, null);
      expect(segments[2].end, 10);
      expect(segments[2].isWithin(CellOffset(0, 12)), isTrue);
      expect(segments[2].isWithin(CellOffset(10, 12)), isTrue);
      expect(segments[2].isWithin(CellOffset(11, 12)), isFalse);
    });
  });
}
