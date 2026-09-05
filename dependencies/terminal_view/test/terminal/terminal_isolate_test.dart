// import 'dart:async';

// import 'package:flutter_test/flutter_test.dart';
// import 'package:terminal_view/terminal/terminal_backend.dart';
// import 'package:terminal_view/terminal/terminal_isolate.dart';

void main() {
  // group('Start behavior tests', () {
  //   test('Using TerminalIsolate when not started throws exception', () {
  //     final fixture = _TestFixture();
  //     expect(() => fixture.uut.terminalWidth, throwsA(isA<Exception>()));
  //   });
  //   test('Using TerminalIsolate after started doesn\'t throw exceptions',
  //       () async {
  //     final fixture = _TestFixture();

  //     await fixture.uut.start(testingDontWaitForBootup: true);

  //     //no throw
  //     fixture.uut.showCursor;
  //   });
  // });
}

// class _TestFixture {
//   _TestFixture() {
//     fakeBackend = FakeBackend();
//     uut = TerminalIsolate(maxLines: 10000, backend: fakeBackend);
//   }

//   late final TerminalIsolate uut;
//   late final FakeBackend fakeBackend;
// }

// class FakeBackend implements TerminalBackend {
//   @override
//   void ackProcessed() {}

//   @override
//   // TODO: implement exitCode
//   Future<int> get exitCode => _exitCodeCompleter.future;

//   @override
//   void init() {
//     _exitCodeCompleter = Completer<int>();
//     _outStream = StreamController<String>();
//     _hasInitBeenCalled = true;
//   }

//   @override
//   Stream<String> get out => _outStream.stream;

//   @override
//   void resize(int width, int height, int pixelWidth, int pixelHeight) {
//     _width = width;
//     _height = height;
//     _pixelWidth = pixelWidth;
//     _pixelHeight = pixelHeight;
//   }

//   @override
//   void terminate() {
//     _isTerminated = true;
//   }

//   @override
//   void write(String _) {}

//   bool get hasInitBeenCalled => _hasInitBeenCalled;
//   bool get isTerminated => _isTerminated;

//   int? get width => _width;
//   int? get height => _height;
//   int? get pixelWidth => _pixelWidth;
//   int? get pixelHeight => _pixelHeight;

//   bool _hasInitBeenCalled = false;
//   bool _isTerminated = false;
//   int? _width;
//   int? _height;
//   int? _pixelWidth;
//   int? _pixelHeight;

//   late final _exitCodeCompleter;
//   late final _outStream;
// }
