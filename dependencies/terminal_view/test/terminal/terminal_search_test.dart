// import 'package:flutter_test/flutter_test.dart';
// import 'package:mockito/annotations.dart';
// import 'package:mockito/mockito.dart';
// import 'package:terminal_view/buffer/buffer.dart';
// import 'package:terminal_view/buffer/line/line.dart';
// import 'package:terminal_view/terminal/cursor.dart';
// import 'package:terminal_view/terminal/terminal_search.dart';
// import 'package:terminal_view/terminal/terminal_search_interaction.dart';
// import 'package:terminal_view/util/circular_list.dart';
// import 'package:terminal_view/util/unicode_v11.dart';

// import 'terminal_search_test.mocks.dart';

// class TerminalSearchTestCircularList extends CircularList<BufferLine> {
//   TerminalSearchTestCircularList(int maxLines) : super(maxLines);
// }

// @GenerateMocks([
//   TerminalSearchInteraction,
//   Buffer,
//   TerminalSearchTestCircularList,
//   BufferLine
// ])
void main() {
  // group('Terminal Search Tests', () {
  //   test('Creation works', () {
  //     _TestFixture();
  //   });

  //   test('Doesn\'t trigger anything when not activated', () {
  //     final fixture = _TestFixture();
  //     verifyNoMoreInteractions(fixture.terminalSearchInteractionMock);
  //     final task = fixture.uut.createSearchTask('testsearch');
  //     task.pattern = "some test";
  //     task.isActive = false;
  //     task.searchResult;
  //   });

  //   test('Basic search works', () {
  //     final fixture = _TestFixture();
  //     fixture.expectTerminalSearchContent(['Simple Content']);
  //     final task = fixture.uut.createSearchTask('testsearch');
  //     task.isActive = true;
  //     task.pattern = 'content';
  //     task.options = TerminalSearchOptions(
  //         caseSensitive: false, matchWholeWord: false, useRegex: false);
  //     final result = task.searchResult;
  //     expect(result.allHits.length, 1);
  //     expect(result.allHits[0].startLineIndex, 0);
  //     expect(result.allHits[0].startIndex, 7);
  //     expect(result.allHits[0].endLineIndex, 0);
  //     expect(result.allHits[0].endIndex, 14);
  //   });

  //   test('Multiline search works', () {
  //     final fixture = _TestFixture();
  //     fixture.expectTerminalSearchContent(['Simple Content', 'Second Line']);
  //     final task = fixture.uut.createSearchTask('testsearch');
  //     task.isActive = true;
  //     task.pattern = 'line';
  //     task.options = TerminalSearchOptions(
  //         caseSensitive: false, matchWholeWord: false, useRegex: false);
  //     final result = task.searchResult;
  //     expect(result.allHits.length, 1);
  //     expect(result.allHits[0].startLineIndex, 1);
  //     expect(result.allHits[0].startIndex, 7);
  //     expect(result.allHits[0].endLineIndex, 1);
  //     expect(result.allHits[0].endIndex, 11);
  //   });

  //   test('Emoji search works', () {
  //     final fixture = _TestFixture();
  //     fixture.expectBufferContentLine([
  //       '🍏',
  //       '🍎',
  //       '🍐',
  //       '🍊',
  //       '🍋',
  //       '🍌',
  //       '🍉',
  //       '🍇',
  //       '🍓',
  //       '🫐',
  //       '🍈',
  //       '🍒',
  //       '🍑'
  //     ]);
  //     final task = fixture.uut.createSearchTask('testsearch');
  //     task.isActive = true;
  //     task.pattern = '🍋';
  //     task.options = TerminalSearchOptions(
  //         caseSensitive: false, matchWholeWord: false, useRegex: false);
  //     final result = task.searchResult;
  //     expect(result.allHits.length, 1);
  //     expect(result.allHits[0].startLineIndex, 0);
  //     expect(result.allHits[0].startIndex, 8);
  //     expect(result.allHits[0].endLineIndex, 0);
  //     expect(result.allHits[0].endIndex, 10);
  //   });

  //   test('CJK search works', () {
  //     final fixture = _TestFixture();
  //     fixture.expectBufferContentLine(['こ', 'ん', 'に', 'ち', 'は', '世', '界']);
  //     final task = fixture.uut.createSearchTask('testsearch');
  //     task.isActive = true;
  //     task.pattern = 'は';
  //     task.options = TerminalSearchOptions(
  //         caseSensitive: false, matchWholeWord: false, useRegex: false);
  //     final result = task.searchResult;
  //     expect(result.allHits.length, 1);
  //     expect(result.allHits[0].startLineIndex, 0);
  //     expect(result.allHits[0].startIndex, 8);
  //     expect(result.allHits[0].endLineIndex, 0);
  //     expect(result.allHits[0].endIndex, 10);
  //   });

  //   test('Finding strings directly on line break works', () {
  //     final fixture = _TestFixture();
  //     fixture.expectTerminalSearchContent([
  //       'The search hit is '.padRight(fixture.terminalWidth - 3) + 'spl',
  //       'it over two lines',
  //     ]);
  //     final task = fixture.uut.createSearchTask('testsearch');
  //     task.isActive = true;
  //     task.pattern = 'split';
  //     task.options = TerminalSearchOptions(
  //         caseSensitive: false, matchWholeWord: false, useRegex: false);
  //     final result = task.searchResult;
  //     expect(result.allHits.length, 1);
  //     expect(result.allHits[0].startLineIndex, 0);
  //     expect(result.allHits[0].startIndex, 77);
  //     expect(result.allHits[0].endLineIndex, 1);
  //     expect(result.allHits[0].endIndex, 2);
  //   });
  // });

  // test('Option: case sensitivity works', () {
  //   final fixture = _TestFixture();
  //   fixture.expectTerminalSearchContent(['Simple Content', 'Second Line']);
  //   final task = fixture.uut.createSearchTask('testsearch');
  //   task.isActive = true;
  //   task.pattern = 'line';
  //   task.options = TerminalSearchOptions(
  //       caseSensitive: true, matchWholeWord: false, useRegex: false);

  //   final result = task.searchResult;
  //   expect(result.allHits.length, 0);

  //   task.pattern = 'Line';
  //   final secondResult = task.searchResult;
  //   expect(secondResult.allHits.length, 1);
  //   expect(secondResult.allHits[0].startLineIndex, 1);
  //   expect(secondResult.allHits[0].startIndex, 7);
  //   expect(secondResult.allHits[0].endLineIndex, 1);
  //   expect(secondResult.allHits[0].endIndex, 11);
  // });

  // test('Option: whole word works', () {
  //   final fixture = _TestFixture();
  //   fixture.expectTerminalSearchContent(['Simple Content', 'Second Line']);
  //   final task = fixture.uut.createSearchTask('testsearch');
  //   task.isActive = true;
  //   task.pattern = 'lin';
  //   task.options = TerminalSearchOptions(
  //       caseSensitive: false, matchWholeWord: true, useRegex: false);

  //   final result = task.searchResult;
  //   expect(result.allHits.length, 0);

  //   task.pattern = 'line';
  //   final secondResult = task.searchResult;
  //   expect(secondResult.allHits.length, 1);
  //   expect(secondResult.allHits[0].startLineIndex, 1);
  //   expect(secondResult.allHits[0].startIndex, 7);
  //   expect(secondResult.allHits[0].endLineIndex, 1);
  //   expect(secondResult.allHits[0].endIndex, 11);
  // });

  // test('Option: regex works', () {
  //   final fixture = _TestFixture();
  //   fixture.expectTerminalSearchContent(['Simple Content', 'Second Line']);
  //   final task = fixture.uut.createSearchTask('testsearch');
  //   task.isActive = true;
  //   task.options = TerminalSearchOptions(
  //       caseSensitive: false, matchWholeWord: false, useRegex: true);

  //   task.pattern =
  //       r'(^|\s)\w{4}($|\s)'; // match exactly 4 characters (and the whitespace before and/or after)
  //   final secondResult = task.searchResult;
  //   expect(secondResult.allHits.length, 1);
  //   expect(secondResult.allHits[0].startLineIndex, 1);
  //   expect(secondResult.allHits[0].startIndex, 6);
  //   expect(secondResult.allHits[0].endLineIndex, 1);
  //   expect(secondResult.allHits[0].endIndex, 12);
  // });

  // test('Retrigger search when a BufferLine got dirty works', () {
  //   final fixture = _TestFixture();
  //   fixture.expectTerminalSearchContent(
  //       ['Simple Content', 'Second Line', 'Third row']);
  //   final task = fixture.uut.createSearchTask('testsearch');
  //   task.isActive = true;
  //   task.options = TerminalSearchOptions(
  //       caseSensitive: false, matchWholeWord: false, useRegex: false);

  //   task.pattern = 'line';
  //   final result = task.searchResult;
  //   expect(result.allHits.length, 1);

  //   // overwrite expectations, nothing dirty => no new search
  //   fixture.expectTerminalSearchContent(
  //       ['Simple Content', 'Second Line', 'Third line'],
  //       isSearchStringCached: true);
  //   task.isActive = false;
  //   task.isActive = true;

  //   final secondResult = task.searchResult;
  //   expect(secondResult.allHits.length,
  //       1); // nothing was dirty => we get the cached search result

  //   // overwrite expectations, one line is dirty => new search
  //   fixture.expectTerminalSearchContent(
  //       ['Simple Content', 'Second Line', 'Third line'],
  //       isSearchStringCached: false,
  //       dirtyIndices: [1]);

  //   final thirdResult = task.searchResult;
  //   expect(thirdResult.allHits.length,
  //       2); //search has happened again so the new content is found

  //   // overwrite expectations, content has changed => new search
  //   fixture.expectTerminalSearchContent(
  //       ['First line', 'Second Line', 'Third line'],
  //       isSearchStringCached: false,
  //       dirtyIndices: [0]);

  //   final fourthResult = task.searchResult;
  //   expect(fourthResult.allHits.length,
  //       3); //search has happened again so the new content is found
  // });
  // test('Handles regex special characters in non regex mode correctly', () {
  //   final fixture = _TestFixture();
  //   fixture.expectTerminalSearchContent(['Simple Content', 'Second Line.\\{']);
  //   final task = fixture.uut.createSearchTask('testsearch');
  //   task.isActive = true;
  //   task.pattern = 'line.\\{';
  //   task.options = TerminalSearchOptions(
  //       caseSensitive: false, matchWholeWord: false, useRegex: false);

  //   final result = task.searchResult;
  //   expect(result.allHits.length, 1);
  //   expect(result.allHits[0].startLineIndex, 1);
  //   expect(result.allHits[0].startIndex, 7);
  //   expect(result.allHits[0].endLineIndex, 1);
  //   expect(result.allHits[0].endIndex, 14);
  // });
  // test('TerminalWidth change leads to retriggering search', () {
  //   final fixture = _TestFixture();
  //   fixture.expectTerminalSearchContent(['Simple Content', 'Second Line']);
  //   final task = fixture.uut.createSearchTask('testsearch');
  //   task.isActive = true;
  //   task.pattern = 'line';
  //   task.options = TerminalSearchOptions(
  //       caseSensitive: false, matchWholeWord: false, useRegex: false);

  //   final result = task.searchResult;
  //   expect(result.allHits.length, 1);

  //   // change data to detect a search re-run
  //   fixture.expectTerminalSearchContent(
  //       ['First line', 'Second Line']); //has 2 hits
  //   task.isActive = false;
  //   task.isActive = true;
  //   final secondResult = task.searchResult;
  //   expect(
  //       secondResult.allHits.length, 1); //nothing changed so the cache is used

  //   fixture.terminalWidth = 79;
  //   task.isActive = false;
  //   task.isActive = true;
  //   final thirdResult = task.searchResult;
  //   //we changed the terminal width which triggered a re-run of the search
  //   expect(thirdResult.allHits.length, 2);
  // });
}

// class _TestFixture {
//   _TestFixture({
//     terminalWidth = 80,
//   }) : _terminalWidth = terminalWidth {
//     uut = TerminalSearch(terminalSearchInteractionMock);
//     when(terminalSearchInteractionMock.terminalWidth).thenReturn(terminalWidth);
//   }

//   int _terminalWidth;
//   int get terminalWidth => _terminalWidth;
//   set terminalWidth(int terminalWidth) {
//     _terminalWidth = terminalWidth;
//     when(terminalSearchInteractionMock.terminalWidth).thenReturn(terminalWidth);
//   }

//   void expectBufferContentLine(
//     List<String> cellData, {
//     isUsingAltBuffer = false,
//   }) {
//     final buffer = _getBufferFromCellData(cellData);
//     when(terminalSearchInteractionMock.buffer).thenReturn(buffer);
//     when(terminalSearchInteractionMock.isUsingAltBuffer())
//         .thenReturn(isUsingAltBuffer);
//   }

//   void expectTerminalSearchContent(
//     List<String> lines, {
//     isUsingAltBuffer = false,
//     isSearchStringCached = true,
//     List<int>? dirtyIndices,
//   }) {
//     final buffer = _getBuffer(lines,
//         isCached: isSearchStringCached, dirtyIndices: dirtyIndices);

//     when(terminalSearchInteractionMock.buffer).thenReturn(buffer);
//     when(terminalSearchInteractionMock.isUsingAltBuffer())
//         .thenReturn(isUsingAltBuffer);
//   }

//   final terminalSearchInteractionMock = MockTerminalSearchInteraction();
//   late final TerminalSearch uut;

//   MockBuffer _getBufferFromCellData(List<String> cellData) {
//     final result = MockBuffer();
//     final circularList = MockTerminalSearchTestCircularList();
//     when(result.lines).thenReturn(circularList);
//     when(circularList[0]).thenReturn(_getBufferLineFromData(cellData));
//     when(circularList.length).thenReturn(1);

//     return result;
//   }

//   MockBuffer _getBuffer(
//     List<String> lines, {
//     isCached = true,
//     List<int>? dirtyIndices,
//   }) {
//     final result = MockBuffer();
//     final circularList = MockTerminalSearchTestCircularList();
//     when(result.lines).thenReturn(circularList);

//     final bufferLines = _getBufferLinesWithSearchContent(
//       lines,
//       isCached: isCached,
//       dirtyIndices: dirtyIndices,
//     );

//     when(circularList[any]).thenAnswer(
//         (realInvocation) => bufferLines[realInvocation.positionalArguments[0]]);
//     when(circularList.length).thenReturn(bufferLines.length);

//     return result;
//   }

//   BufferLine _getBufferLineFromData(List<String> cellData) {
//     final result = BufferLine(length: _terminalWidth);
//     int currentIndex = 0;
//     for (var data in cellData) {
//       final codePoint = data.runes.first;
//       final width = unicodeV11.wcwidth(codePoint);
//       result.cellInitialize(
//         currentIndex,
//         content: codePoint,
//         width: width,
//         cursor: Cursor(bg: 0, fg: 0, flags: 0),
//       );
//       currentIndex++;
//       for (int i = 1; i < width; i++) {
//         result.cellInitialize(
//           currentIndex,
//           content: 0,
//           width: 0,
//           cursor: Cursor(bg: 0, fg: 0, flags: 0),
//         );
//         currentIndex++;
//       }
//     }
//     return result;
//   }

//   List<MockBufferLine> _getBufferLinesWithSearchContent(
//     List<String> content, {
//     isCached = true,
//     List<int>? dirtyIndices,
//   }) {
//     final result = List<MockBufferLine>.empty(growable: true);
//     for (int i = 0; i < content.length; i++) {
//       final bl = MockBufferLine();
//       when(bl.hasCachedSearchString).thenReturn(isCached);
//       when(bl.toSearchString(any)).thenReturn(content[i]);
//       if (dirtyIndices?.contains(i) ?? false) {
//         when(bl.isTagDirty(any)).thenReturn(true);
//       } else {
//         when(bl.isTagDirty(any)).thenReturn(false);
//       }
//       result.add(bl);
//     }

//     return result;
//   }
// }
