// import 'package:flutter_test/flutter_test.dart';
// import 'package:terminal_view/buffer/line/line.dart';
// import 'package:terminal_view/terminal/cursor.dart';

void main() {
  // group("BufferLine Tests", () {
  //   test("creation test", () {
  //     final line = BufferLine();
  //     expect(line, isNotNull);
  //   });

  //   test("set isWrapped", () {
  //     final line = BufferLine(isWrapped: false);
  //     expect(line.isWrapped, isFalse);

  //     line.isWrapped = true;
  //     expect(line.isWrapped, isTrue);

  //     line.isWrapped = false;
  //     expect(line.isWrapped, isFalse);
  //   });

  //   test("ensure() works", () {
  //     final line = BufferLine(length: 10);
  //     expect(() => line.cellSetContent(1000, 65), throwsRangeError);

  //     line.ensure(1000);
  //     line.cellSetContent(1000, 65);
  //   });

  //   test("insert() works", () {
  //     final line = BufferLine(length: 10);
  //     line.cellSetContent(0, 65);
  //     line.cellSetContent(1, 66);
  //     line.cellSetContent(2, 67);

  //     line.insert(1);

  //     final result = [
  //       line.cellGetContent(0),
  //       line.cellGetContent(1),
  //       line.cellGetContent(2),
  //       line.cellGetContent(3),
  //     ];

  //     expect(result, equals([65, 0, 66, 67]));
  //   });

  //   test("insertN() works", () {
  //     final line = BufferLine(length: 10);
  //     line.cellSetContent(0, 65);
  //     line.cellSetContent(1, 66);
  //     line.cellSetContent(2, 67);

  //     line.insertN(1, 2);

  //     final result = [
  //       line.cellGetContent(0),
  //       line.cellGetContent(1),
  //       line.cellGetContent(2),
  //       line.cellGetContent(3),
  //       line.cellGetContent(4),
  //     ];

  //     expect(result, equals([65, 0, 0, 66, 67]));
  //   });

  //   test("removeN() works", () {
  //     final line = BufferLine(length: 10);
  //     line.cellSetContent(0, 65);
  //     line.cellSetContent(1, 66);
  //     line.cellSetContent(2, 67);
  //     line.cellSetContent(3, 68);
  //     line.cellSetContent(4, 69);

  //     line.removeN(1, 2);

  //     final result = [
  //       line.cellGetContent(0),
  //       line.cellGetContent(1),
  //       line.cellGetContent(2),
  //       line.cellGetContent(3),
  //       line.cellGetContent(4),
  //     ];

  //     expect(result, equals([65, 68, 69, 0, 0]));
  //   });

  //   test("clear() works", () {
  //     final line = BufferLine(length: 10);
  //     line.cellSetContent(1, 65);
  //     line.cellSetContent(2, 66);
  //     line.cellSetContent(3, 67);
  //     line.cellSetContent(4, 68);
  //     line.cellSetContent(5, 69);

  //     line.clear();

  //     final result = [
  //       line.cellGetContent(1),
  //       line.cellGetContent(2),
  //       line.cellGetContent(3),
  //       line.cellGetContent(4),
  //       line.cellGetContent(5),
  //     ];

  //     expect(result, equals([0, 0, 0, 0, 0]));
  //   });

  //   test("cellInitialize() works", () {
  //     final line = BufferLine(length: 10);
  //     line.cellInitialize(
  //       0,
  //       content: 0x01,
  //       width: 0x02,
  //       cursor: Cursor(fg: 0x03, bg: 0x04, flags: 0x05),
  //     );

  //     final result = [
  //       line.cellGetContent(0),
  //       line.cellGetWidth(0),
  //       line.cellGetFgColor(0),
  //       line.cellGetBgColor(0),
  //       line.cellGetFlags(0),
  //     ];

  //     expect(result, equals([0x01, 0x02, 0x03, 0x04, 0x05]));
  //   });

  //   test("cellHasContent() works", () {
  //     final line = BufferLine(length: 10);

  //     line.cellSetContent(0, 0x01);
  //     expect(line.cellHasContent(0), isTrue);

  //     line.cellSetContent(0, 0x00);
  //     expect(line.cellHasContent(0), isFalse);
  //   });

  //   test("cellGetContent() and cellSetContent() works", () {
  //     final line = BufferLine(length: 10);
  //     final content = 0x01;
  //     line.cellSetContent(0, content);
  //     expect(line.cellGetContent(0), equals(content));
  //   });

  //   test("cellGetFgColor() and cellSetFgColor() works", () {
  //     final line = BufferLine(length: 10);
  //     final content = 0x01;
  //     line.cellSetFgColor(0, content);
  //     expect(line.cellGetFgColor(0), equals(content));
  //   });

  //   test("cellGetBgColor() and cellSetBgColor() works", () {
  //     final line = BufferLine(length: 10);
  //     final content = 0x01;
  //     line.cellSetBgColor(0, content);
  //     expect(line.cellGetBgColor(0), equals(content));
  //   });

  //   test("cellHasFlag() and cellSetFlag() works", () {
  //     final line = BufferLine(length: 10);
  //     final flag = 0x03;
  //     line.cellSetFlag(0, flag);
  //     expect(line.cellHasFlag(0, flag), isTrue);
  //   });

  //   test("cellGetFlags() and cellSetFlags() works", () {
  //     final line = BufferLine(length: 10);
  //     final content = 0x01;
  //     line.cellSetFlags(0, content);
  //     expect(line.cellGetFlags(0), equals(content));
  //   });

  //   test("cellGetWidth() and cellSetWidth() works", () {
  //     final line = BufferLine(length: 10);
  //     final content = 0x01;
  //     line.cellSetWidth(0, content);
  //     expect(line.cellGetWidth(0), equals(content));
  //   });

  //   test("getTrimmedLength() works", () {
  //     final line = BufferLine(length: 10);
  //     expect(line.getTrimmedLength(), equals(0));

  //     line.cellSetContent(5, 0x01);
  //     expect(line.getTrimmedLength(), equals(5));

  //     line.clear();
  //     expect(line.getTrimmedLength(), equals(0));
  //   });

  //   test("copyCellsFrom() works", () {
  //     final line1 = BufferLine(length: 10);
  //     final line2 = BufferLine(length: 10);

  //     line1.cellSetContent(0, 123);
  //     line1.cellSetContent(1, 124);
  //     line1.cellSetContent(2, 125);

  //     line2.copyCellsFrom(line1, 1, 3, 2);

  //     expect(line2.cellGetContent(2), equals(0));
  //     expect(line2.cellGetContent(3), equals(124));
  //     expect(line2.cellGetContent(4), equals(125));
  //     expect(line2.cellGetContent(5), equals(0));
  //   });

  //   test("removeRange() works", () {
  //     final line = BufferLine(length: 10);
  //     line.cellSetContent(0, 65);
  //     line.cellSetContent(1, 66);
  //     line.cellSetContent(2, 67);
  //     line.cellSetContent(3, 68);
  //     line.cellSetContent(4, 69);

  //     line.removeRange(1, 3);

  //     final result = [
  //       line.cellGetContent(0),
  //       line.cellGetContent(1),
  //       line.cellGetContent(2),
  //       line.cellGetContent(3),
  //       line.cellGetContent(4),
  //     ];

  //     expect(result, equals([65, 68, 69, 0, 0]));
  //   });

  //   test("clearRange() works", () {
  //     final line = BufferLine(length: 10);
  //     line.cellSetContent(0, 65);
  //     line.cellSetContent(1, 66);
  //     line.cellSetContent(2, 67);
  //     line.cellSetContent(3, 68);
  //     line.cellSetContent(4, 69);

  //     line.clearRange(1, 3);

  //     final result = [
  //       line.cellGetContent(0),
  //       line.cellGetContent(1),
  //       line.cellGetContent(2),
  //       line.cellGetContent(3),
  //       line.cellGetContent(4),
  //     ];

  //     expect(result, equals([65, 0, 0, 68, 69]));
  //   });
  // });
}
