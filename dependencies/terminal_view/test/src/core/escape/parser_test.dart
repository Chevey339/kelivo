import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:terminal_view/terminal_view.dart';

@GenerateNiceMocks([MockSpec<EscapeHandler>()])
import 'parser_test.mocks.dart';

void main() {
  group('EscapeParser', () {
    test('can parse window manipulation', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[8;24;80t');
      verify(parser.handler.resize(80, 24));
    });

    test('does not merge SGR params separated by semicolon', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[0;4m');

      verify(parser.handler.resetCursorStyle());
      verify(parser.handler.setCursorUnderline());
      verifyNever(parser.handler.unsupportedStyle(4));
    });

    test('does not merge DEC private mode params', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[?1006;1000h');

      verify(parser.handler.setMouseReportMode(MouseReportMode.sgr));
      verify(parser.handler.setMouseMode(MouseMode.upDownScroll));
    });

    test('supports trailing empty SGR param as reset', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[4;m');

      verify(parser.handler.setCursorUnderline());
      verify(parser.handler.resetCursorStyle());
    });

    test('SGR 22 clears both bold and faint', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[22m');

      verify(parser.handler.unsetCursorBold());
      verify(parser.handler.unsetCursorFaint());
    });
  });
}
