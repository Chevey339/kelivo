import 'dart:math' show max;

import 'package:terminal_view/src/base/observable.dart';
import 'package:terminal_view/src/core/buffer/buffer.dart';
import 'package:terminal_view/src/core/buffer/cell_offset.dart';
import 'package:terminal_view/src/core/buffer/line.dart';
import 'package:terminal_view/src/core/cursor.dart';
import 'package:terminal_view/src/core/escape/emitter.dart';
import 'package:terminal_view/src/core/escape/handler.dart';
import 'package:terminal_view/src/core/escape/parser.dart';
import 'package:terminal_view/src/core/input/handler.dart';
import 'package:terminal_view/src/core/input/keys.dart';
import 'package:terminal_view/src/core/mouse/button.dart';
import 'package:terminal_view/src/core/mouse/button_state.dart';
import 'package:terminal_view/src/core/mouse/handler.dart';
import 'package:terminal_view/src/core/mouse/mode.dart';
import 'package:terminal_view/src/core/platform.dart';
import 'package:terminal_view/src/core/state.dart';
import 'package:terminal_view/src/core/tabs.dart';
import 'package:terminal_view/src/core/cursor_type.dart';
import 'package:terminal_view/src/utils/ascii.dart';
import 'package:terminal_view/src/utils/circular_buffer.dart';

const _kSynchronizedUpdateTimeoutMs = 150;

/// [Terminal] is an interface to interact with command line applications. It
/// translates escape sequences from the application into updates to the
/// [buffer] and events such as [onTitleChange] or [onBell], as well as
/// translating user input into escape sequences that the application can
/// understand.
class Terminal with Observable implements TerminalState, EscapeHandler {
  /// The number of lines that the scrollback buffer can hold. If the buffer
  /// exceeds this size, the lines at the top of the buffer will be removed.
  final int maxLines;

  /// Function that is called when the program requests the terminal to ring
  /// the bell. If not set, the terminal will do nothing.
  void Function()? onBell;

  /// Function that is called when the program requests the terminal to change
  /// the title of the window to [title].
  void Function(String title)? onTitleChange;

  /// Function that is called when the program requests the terminal to change
  /// the icon of the window. [icon] is the name of the icon.
  void Function(String icon)? onIconChange;

  /// Function that is called when the terminal emits data to the underlying
  /// program. This is typically caused by user inputs from [textInput],
  /// [keyInput], [mouseInput], or [paste].
  void Function(String data)? onOutput;

  /// Function that is called when the dimensions of the terminal change.
  void Function(int width, int height, int pixelWidth, int pixelHeight)?
      onResize;

  /// The [TerminalInputHandler] used by this terminal. [defaultInputHandler] is
  /// used when not specified. User of this class can provide their own
  /// implementation of [TerminalInputHandler] or extend [defaultInputHandler]
  /// with [CascadeInputHandler].
  TerminalInputHandler? inputHandler;

  TerminalMouseHandler? mouseHandler;

  /// The callback that is called when the terminal receives a unrecognized
  /// escape sequence.
  void Function(String code, List<String> args)? onPrivateOSC;

  /// Flag to toggle os specific behaviors.
  final TerminalTargetPlatform platform;

  /// Characters that break selection when double clicking. If not set, the
  /// [Buffer.defaultWordSeparators] will be used.
  final Set<int>? wordSeparators;

  Terminal({
    this.maxLines = 1000,
    this.onBell,
    this.onTitleChange,
    this.onIconChange,
    this.onOutput,
    this.onResize,
    this.platform = TerminalTargetPlatform.unknown,
    this.inputHandler = defaultInputHandler,
    this.mouseHandler = defaultMouseHandler,
    this.onPrivateOSC,
    this.reflowEnabled = true,
    this.wordSeparators,
  });

  late final _parser = EscapeParser(this);

  final _emitter = const EscapeEmitter();

  late var _buffer = _mainBuffer;

  late final _mainBuffer = Buffer(
    this,
    maxLines: maxLines,
    isAltBuffer: false,
    wordSeparators: wordSeparators,
  );

  late final _altBuffer = Buffer(
    this,
    maxLines: maxLines,
    isAltBuffer: true,
    wordSeparators: wordSeparators,
  );

  final _tabStops = TabStops();

  /// The last character written to the buffer. Used to implement some escape
  /// sequences that repeat the last character.
  var _precedingCodepoint = 0;

  /* TerminalState */

  int _viewWidth = 80;

  int _viewHeight = 24;

  final _cursorStyle = CursorStyle();

  bool _insertMode = false;

  bool _lineFeedMode = false;

  bool _cursorKeysMode = false;

  bool _reverseDisplayMode = false;

  bool _originMode = false;

  bool _autoWrapMode = true;

  MouseMode _mouseMode = MouseMode.none;

  MouseReportMode _mouseReportMode = MouseReportMode.normal;

  bool _cursorBlinkMode = false;

  bool _cursorVisibleMode = true;

  bool _appKeypadMode = false;

  bool _reportFocusMode = false;

  bool _altBufferMouseScrollMode = false;

  bool _bracketedPasteMode = false;

  /// Origin and autowrap modes captured by DECSC/SCOSC, restored by
  /// DECRC/SCORC (xterm saves these alongside the cursor position).
  var _savedOriginMode = false;

  var _savedAutoWrapMode = true;

  bool _synchronizedUpdate = false;

  int _synchronizedUpdateStartedAt = 0;

  TerminalCursorType _cursorShape = TerminalCursorType.block;

  /* State getters */

  /// Number of cells in a terminal row.
  @override
  int get viewWidth => _viewWidth;

  /// Number of rows in this terminal.
  @override
  int get viewHeight => _viewHeight;

  @override
  CursorStyle get cursor => _cursorStyle;

  @override
  bool get insertMode => _insertMode;

  @override
  bool get lineFeedMode => _lineFeedMode;

  @override
  bool get cursorKeysMode => _cursorKeysMode;

  @override
  bool get reverseDisplayMode => _reverseDisplayMode;

  @override
  bool get originMode => _originMode;

  @override
  bool get autoWrapMode => _autoWrapMode;

  @override
  MouseMode get mouseMode => _mouseMode;

  @override
  MouseReportMode get mouseReportMode => _mouseReportMode;

  @override
  bool get cursorBlinkMode => _cursorBlinkMode;

  @override
  bool get cursorVisibleMode => _cursorVisibleMode;

  @override
  bool get appKeypadMode => _appKeypadMode;

  @override
  bool get reportFocusMode => _reportFocusMode;

  @override
  bool get altBufferMouseScrollMode => _altBufferMouseScrollMode;

  @override
  bool get bracketedPasteMode => _bracketedPasteMode;

  /// The cursor shape the program asked for with DECSCUSR. A view is free to
  /// ignore it and draw the shape its own configuration asks for.
  TerminalCursorType get cursorShape => _cursorShape;

  /// Current active buffer of the terminal. This is initially [mainBuffer] and
  /// can be switched back and forth from [altBuffer] to [mainBuffer] when
  /// the underlying program requests it.
  Buffer get buffer => _buffer;

  Buffer get mainBuffer => _mainBuffer;

  Buffer get altBuffer => _altBuffer;

  bool get isUsingAltBuffer => _buffer == _altBuffer;

  /// Lines of the active buffer.
  IndexAwareCircularBuffer<BufferLine> get lines => _buffer.lines;

  /// Whether the terminal performs reflow when the viewport size changes or
  /// simply truncates lines. true by default.
  @override
  bool reflowEnabled;

  /// Writes the data from the underlying program to the terminal. Calling this
  /// updates the states of the terminal and emits events such as [onBell] or
  /// [onTitleChange] when the escape sequences in [data] request it.
  void write(String data) {
    _parser.write(data);

    if (_synchronizedUpdate && !_synchronizedUpdateExpired) {
      return;
    }

    _synchronizedUpdate = false;
    notifyListeners();
  }

  /// A program that enables synchronized output and then dies would freeze the
  /// screen forever, so the hold is given up after a deadline the way xterm and
  /// kitty give theirs up.
  bool get _synchronizedUpdateExpired {
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - _synchronizedUpdateStartedAt;
    return elapsed > _kSynchronizedUpdateTimeoutMs;
  }

  /// Sends a key event to the underlying program.
  ///
  /// See also:
  /// - [charInput]
  /// - [textInput]
  /// - [paste]
  bool keyInput(
    TerminalKey key, {
    bool shift = false,
    bool alt = false,
    bool ctrl = false,
  }) {
    final output = inputHandler?.call(
      TerminalKeyboardEvent(
        key: key,
        shift: shift,
        alt: alt,
        ctrl: ctrl,
        state: this,
        altBuffer: isUsingAltBuffer,
        platform: platform,
      ),
    );

    if (output != null) {
      onOutput?.call(output);
      return true;
    }

    return false;
  }

  /// Similary to [keyInput], but takes a character as input instead of a
  /// [TerminalKey].
  ///
  /// See also:
  /// - [keyInput]
  /// - [textInput]
  /// - [paste]
  bool charInput(
    int charCode, {
    bool alt = false,
    bool ctrl = false,
  }) {
    if (ctrl) {
      // a(97) ~ z(122)
      if (charCode >= Ascii.a && charCode <= Ascii.z) {
        final output = charCode - Ascii.a + 1;
        onOutput?.call(String.fromCharCode(output));
        return true;
      }

      // [(91) ~ _(95)
      if (charCode >= Ascii.openBracket && charCode <= Ascii.underscore) {
        final output = charCode - Ascii.openBracket + 27;
        onOutput?.call(String.fromCharCode(output));
        return true;
      }
    }

    if (alt && platform != TerminalTargetPlatform.macos) {
      if (charCode >= Ascii.a && charCode <= Ascii.z) {
        final code = charCode - Ascii.a + 65;
        final input = [0x1b, code];
        onOutput?.call(String.fromCharCodes(input));
        return true;
      }
    }

    return false;
  }

  /// Sends regular text input to the underlying program.
  ///
  /// See also:
  /// - [keyInput]
  /// - [charInput]
  /// - [paste]
  void textInput(String text) {
    onOutput?.call(text);
  }

  /// Similar to [textInput], except that when the program tells the terminal
  /// that it supports [bracketedPasteMode], the text is wrapped in escape
  /// sequences to indicate that it is a paste operation. Prefer this method
  /// over [textInput] when pasting text.
  ///
  /// See also:
  /// - [textInput]
  void paste(String text) {
    if (_bracketedPasteMode) {
      onOutput?.call(_emitter.bracketedPaste(text));
    } else {
      textInput(text);
    }
  }

  bool mouseInput(
    TerminalMouseButton button,
    TerminalMouseButtonState buttonState,
    CellOffset position,
  ) {
    final output = mouseHandler?.call(TerminalMouseEvent(
      button: button,
      buttonState: buttonState,
      position: position,
      state: this,
      platform: platform,
    ));
    if (output != null) {
      onOutput?.call(output);
      return true;
    }
    return false;
  }

  /// Resize the terminal screen. [newWidth] and [newHeight] should be greater
  /// than 0. Text reflow is currently not implemented and will be avaliable in
  /// the future.
  @override
  void resize(
    int newWidth,
    int newHeight, [
    int? pixelWidth,
    int? pixelHeight,
  ]) {
    newWidth = max(newWidth, 1);
    newHeight = max(newHeight, 1);

    onResize?.call(newWidth, newHeight, pixelWidth ?? 0, pixelHeight ?? 0);

    //we need to resize both buffers so that they are ready when we switch between them
    _altBuffer.resize(_viewWidth, _viewHeight, newWidth, newHeight);
    _mainBuffer.resize(_viewWidth, _viewHeight, newWidth, newHeight);

    _viewWidth = newWidth;
    _viewHeight = newHeight;

    if (buffer == _altBuffer) {
      buffer.clearScrollback();
    }

    _altBuffer.resetVerticalMargins();
    _mainBuffer.resetVerticalMargins();
  }

  @override
  String toString() {
    return 'Terminal(#$hashCode, $_viewWidth x $_viewHeight, ${_buffer.height} lines)';
  }

  /* Handlers */

  @override
  void writeChar(int char) {
    _precedingCodepoint = char;
    _buffer.writeChar(char);
  }

  /* SBC */

  @override
  void bell() {
    onBell?.call();
  }

  @override
  void backspaceReturn() {
    _buffer.backspace();
  }

  @override
  void tab() {
    final nextStop = _tabStops.find(_buffer.cursorX + 1, _viewWidth);

    if (nextStop != null) {
      _buffer.setCursorX(nextStop);
    } else {
      _buffer.setCursorX(_viewWidth);
      _buffer.cursorGoForward(); // Enter pending-wrap state
    }
  }

  @override
  void lineFeed() {
    _buffer.lineFeed();
  }

  @override
  void carriageReturn() {
    _buffer.setCursorX(0);
  }

  @override
  void shiftOut() {
    _buffer.charset.use(1);
  }

  @override
  void shiftIn() {
    _buffer.charset.use(0);
  }

  @override
  void unknownSBC(int char) {
    // no-op
  }

  /* ANSI sequence */

  @override
  void saveCursor() {
    _buffer.saveCursor();
    _savedOriginMode = _originMode;
    _savedAutoWrapMode = _autoWrapMode;
  }

  @override
  void restoreCursor() {
    _buffer.restoreCursor();
    _originMode = _savedOriginMode;
    _autoWrapMode = _savedAutoWrapMode;
  }

  @override
  void index() {
    _buffer.index();
  }

  @override
  void nextLine() {
    _buffer.index();
    _buffer.setCursorX(0);
  }

  @override
  void setTapStop() {
    _tabStops.setAt(_buffer.cursorX);
  }

  @override
  void reverseIndex() {
    _buffer.reverseIndex();
  }

  @override
  void designateCharset(int charset, int name) {
    _buffer.charset.designate(charset, name);
  }

  @override
  void fullReset() {
    _mainBuffer.clear();
    _altBuffer.clear();
    _buffer = _mainBuffer;
    _tabStops.reset();
    _cursorStyle.reset();
    _insertMode = false;
    _lineFeedMode = false;
    _cursorKeysMode = false;
    _reverseDisplayMode = false;
    _originMode = false;
    _autoWrapMode = true;
    _mouseMode = MouseMode.none;
    _mouseReportMode = MouseReportMode.normal;
    _cursorBlinkMode = false;
    _cursorVisibleMode = true;
    _appKeypadMode = false;
    _reportFocusMode = false;
    _altBufferMouseScrollMode = false;
    _bracketedPasteMode = false;
    _savedOriginMode = false;
    _savedAutoWrapMode = true;
    _cursorShape = TerminalCursorType.block;
    _synchronizedUpdate = false;
    _mainBuffer.softReset();
    _altBuffer.softReset();
  }

  @override
  void unkownEscape(int char) {
    // no-op
  }

  /* CSI */

  @override
  void repeatPreviousCharacter(int count) {
    if (_precedingCodepoint == 0) {
      return;
    }

    for (var i = 0; i < count; i++) {
      _buffer.writeChar(_precedingCodepoint);
    }
  }

  @override
  void setCursor(int x, int y) {
    _buffer.setCursor(x, y);
  }

  @override
  void setCursorX(int x) {
    _buffer.setCursorX(x);
  }

  @override
  void setCursorY(int y) {
    _buffer.setCursorY(y);
  }

  @override
  void moveCursorX(int offset) {
    _buffer.moveCursorX(offset);
  }

  @override
  void moveCursorY(int n) {
    _buffer.moveCursorY(n);
  }

  @override
  void clearTabStopUnderCursor() {
    _tabStops.clearAt(_buffer.cursorX);
  }

  @override
  void clearAllTabStops() {
    _tabStops.clearAll();
  }

  @override
  void sendPrimaryDeviceAttributes() {
    onOutput?.call(_emitter.primaryDeviceAttributes());
  }

  @override
  void sendSecondaryDeviceAttributes() {
    onOutput?.call(_emitter.secondaryDeviceAttributes());
  }

  @override
  void sendTertiaryDeviceAttributes() {
    onOutput?.call(_emitter.tertiaryDeviceAttributes());
  }

  @override
  void sendOperatingStatus() {
    onOutput?.call(_emitter.operatingStatus());
  }

  @override
  void sendCursorPosition() {
    final y =
        _originMode ? _buffer.cursorY - _buffer.marginTop : _buffer.cursorY;
    onOutput?.call(_emitter.cursorPosition(_buffer.cursorX, y));
  }

  @override
  void setMargins(int top, [int? bottom]) {
    bottom ??= viewHeight - 1;

    // A region smaller than two lines is not applied at all (xterm requires
    // the bottom to be below the top).
    if (bottom <= top) {
      return;
    }

    _buffer.setVerticalMargins(top, bottom);

    // DECSTBM moves the cursor to the home position (DEC STD 070).
    _buffer.setCursor(0, 0);
  }

  @override
  void cursorNextLine(int amount) {
    _buffer.moveCursorY(amount);
    _buffer.setCursorX(0);
  }

  @override
  void cursorPrecedingLine(int amount) {
    _buffer.moveCursorY(-amount);
    _buffer.setCursorX(0);
  }

  @override
  void eraseDisplayBelow() {
    _buffer.eraseDisplayFromCursor();
  }

  @override
  void eraseDisplayAbove() {
    _buffer.eraseDisplayToCursor();
  }

  @override
  void eraseDisplay() {
    _buffer.eraseDisplay();
  }

  @override
  void eraseScrollbackOnly() {
    _buffer.clearScrollback();
  }

  @override
  void eraseLineRight() {
    _buffer.eraseLineFromCursor();
  }

  @override
  void eraseLineLeft() {
    _buffer.eraseLineToCursor();
  }

  @override
  void eraseLine() {
    _buffer.eraseLine();
  }

  @override
  void insertLines(int amount) {
    _buffer.insertLines(amount);
  }

  @override
  void deleteLines(int amount) {
    _buffer.deleteLines(amount);
  }

  @override
  void deleteChars(int amount) {
    _buffer.deleteChars(amount);
  }

  @override
  void scrollUp(int amount) {
    _buffer.scrollUp(amount);
  }

  @override
  void scrollDown(int amount) {
    _buffer.scrollDown(amount);
  }

  @override
  void eraseChars(int amount) {
    _buffer.eraseChars(amount);
  }

  @override
  void insertBlankChars(int amount) {
    _buffer.insertBlankChars(amount);
  }

  @override
  void sendSize() {
    onOutput?.call(_emitter.size(viewHeight, viewWidth));
  }

  @override
  void backwardTab(int amount) {
    for (var i = 0; i < amount; i++) {
      final stop = _tabStops.findBackward(_buffer.cursorX);
      if (stop == null) {
        _buffer.setCursorX(0);
        return;
      }
      _buffer.setCursorX(stop);
    }
  }

  @override
  void softReset() {
    _insertMode = false;
    _originMode = false;
    _autoWrapMode = true;
    _cursorVisibleMode = true;
    _appKeypadMode = false;
    _cursorStyle.reset();
    _savedOriginMode = false;
    _savedAutoWrapMode = true;
    _buffer.softReset();
  }

  @override
  void reportMode(int mode, {required bool isDec}) {
    onOutput?.call(
      _emitter.reportMode(mode, _modeState(mode, isDec: isDec), isDec: isDec),
    );
  }

  int _modeState(int mode, {required bool isDec}) {
    bool? enabled;

    if (!isDec) {
      switch (mode) {
        case 4:
          enabled = _insertMode;
        case 20:
          enabled = _lineFeedMode;
      }
    } else {
      switch (mode) {
        case 1:
          enabled = _cursorKeysMode;
        case 5:
          enabled = _reverseDisplayMode;
        case 6:
          enabled = _originMode;
        case 7:
          enabled = _autoWrapMode;
        case 12:
        case 13:
          enabled = _cursorBlinkMode;
        case 25:
          enabled = _cursorVisibleMode;
        case 66:
          enabled = _appKeypadMode;
        case 1000:
          enabled = _mouseMode == MouseMode.upDownScroll;
        case 1002:
          enabled = _mouseMode == MouseMode.upDownScrollDrag;
        case 1003:
          enabled = _mouseMode == MouseMode.upDownScrollMove;
        case 1004:
          enabled = _reportFocusMode;
        case 1006:
          enabled = _mouseReportMode == MouseReportMode.sgr;
        case 1007:
          enabled = _altBufferMouseScrollMode;
        case 47:
        case 1047:
        case 1049:
          enabled = isUsingAltBuffer;
        case 2004:
          enabled = _bracketedPasteMode;
        case 2026:
          enabled = _synchronizedUpdate;
      }
    }

    if (enabled == null) return 0;
    return enabled ? 1 : 2;
  }

  @override
  void setCursorStyleShape(int shape) {
    switch (shape) {
      case 0:
      case 1:
        _cursorShape = TerminalCursorType.block;
        _cursorBlinkMode = true;
      case 2:
        _cursorShape = TerminalCursorType.block;
        _cursorBlinkMode = false;
      case 3:
        _cursorShape = TerminalCursorType.underline;
        _cursorBlinkMode = true;
      case 4:
        _cursorShape = TerminalCursorType.underline;
        _cursorBlinkMode = false;
      case 5:
        _cursorShape = TerminalCursorType.verticalBar;
        _cursorBlinkMode = true;
      case 6:
        _cursorShape = TerminalCursorType.verticalBar;
        _cursorBlinkMode = false;
    }
  }

  @override
  void unknownCSI(int finalByte) {
    // no-op
  }

  /* Modes */

  @override
  void setInsertMode(bool enabled) {
    _insertMode = enabled;
  }

  @override
  void setLineFeedMode(bool enabled) {
    _lineFeedMode = enabled;
  }

  @override
  void setUnknownMode(int mode, bool enabled) {
    // no-op
  }

  /* DEC Private modes */

  @override
  void setCursorKeysMode(bool enabled) {
    _cursorKeysMode = enabled;
  }

  @override
  void setReverseDisplayMode(bool enabled) {
    _reverseDisplayMode = enabled;
  }

  @override
  void setOriginMode(bool enabled) {
    _originMode = enabled;
  }

  @override
  void setColumnMode(bool enabled) {
    // no-op
  }

  @override
  void setAutoWrapMode(bool enabled) {
    _autoWrapMode = enabled;
  }

  @override
  void setMouseMode(MouseMode mode) {
    _mouseMode = mode;
  }

  @override
  void setCursorBlinkMode(bool enabled) {
    _cursorBlinkMode = enabled;
  }

  @override
  void setCursorVisibleMode(bool enabled) {
    _cursorVisibleMode = enabled;
  }

  @override
  void useAltBuffer() {
    _buffer = _altBuffer;
  }

  @override
  void useMainBuffer() {
    _buffer = _mainBuffer;
  }

  @override
  void clearAltBuffer() {
    _altBuffer.clear();
  }

  @override
  void setAppKeypadMode(bool enabled) {
    _appKeypadMode = enabled;
  }

  @override
  void setReportFocusMode(bool enabled) {
    _reportFocusMode = enabled;
  }

  @override
  void setMouseReportMode(MouseReportMode mode) {
    _mouseReportMode = mode;
  }

  @override
  void setAltBufferMouseScrollMode(bool enabled) {
    _altBufferMouseScrollMode = enabled;
  }

  @override
  void setBracketedPasteMode(bool enabled) {
    _bracketedPasteMode = enabled;
  }

  @override
  void setSynchronizedUpdateMode(bool enabled) {
    if (enabled && !_synchronizedUpdate) {
      _synchronizedUpdateStartedAt = DateTime.now().millisecondsSinceEpoch;
    }
    _synchronizedUpdate = enabled;
  }

  @override
  void setUnknownDecMode(int mode, bool enabled) {
    // no-op
  }

  /* Select Graphic Rendition (SGR) */

  @override
  void resetCursorStyle() {
    _cursorStyle.reset();
  }

  @override
  void setCursorBold() {
    _cursorStyle.setBold();
  }

  @override
  void setCursorFaint() {
    _cursorStyle.setFaint();
  }

  @override
  void setCursorItalic() {
    _cursorStyle.setItalic();
  }

  @override
  void setCursorUnderline() {
    _cursorStyle.setUnderline();
  }

  @override
  void setCursorBlink() {
    _cursorStyle.setBlink();
  }

  @override
  void setCursorInverse() {
    _cursorStyle.setInverse();
  }

  @override
  void setCursorInvisible() {
    _cursorStyle.setInvisible();
  }

  @override
  void setCursorStrikethrough() {
    _cursorStyle.setStrikethrough();
  }

  @override
  void unsetCursorBold() {
    _cursorStyle.unsetBold();
  }

  @override
  void unsetCursorFaint() {
    _cursorStyle.unsetFaint();
  }

  @override
  void unsetCursorItalic() {
    _cursorStyle.unsetItalic();
  }

  @override
  void unsetCursorUnderline() {
    _cursorStyle.unsetUnderline();
  }

  @override
  void unsetCursorBlink() {
    _cursorStyle.unsetBlink();
  }

  @override
  void unsetCursorInverse() {
    _cursorStyle.unsetInverse();
  }

  @override
  void unsetCursorInvisible() {
    _cursorStyle.unsetInvisible();
  }

  @override
  void unsetCursorStrikethrough() {
    _cursorStyle.unsetStrikethrough();
  }

  @override
  void setForegroundColor16(int color) {
    _cursorStyle.setForegroundColor16(color);
  }

  @override
  void setForegroundColor256(int index) {
    _cursorStyle.setForegroundColor256(index);
  }

  @override
  void setForegroundColorRgb(int r, int g, int b) {
    _cursorStyle.setForegroundColorRgb(r, g, b);
  }

  @override
  void resetForeground() {
    _cursorStyle.resetForegroundColor();
  }

  @override
  void setBackgroundColor16(int color) {
    _cursorStyle.setBackgroundColor16(color);
  }

  @override
  void setBackgroundColor256(int index) {
    _cursorStyle.setBackgroundColor256(index);
  }

  @override
  void setBackgroundColorRgb(int r, int g, int b) {
    _cursorStyle.setBackgroundColorRgb(r, g, b);
  }

  @override
  void resetBackground() {
    _cursorStyle.resetBackgroundColor();
  }

  @override
  void unsupportedStyle(int param) {
    // no-op
  }

  /* OSC */

  @override
  void setTitle(String name) {
    onTitleChange?.call(name);
  }

  @override
  void setIconName(String name) {
    onIconChange?.call(name);
  }

  @override
  void unknownOSC(String ps, List<String> pt) {
    onPrivateOSC?.call(ps, pt);
  }
}
