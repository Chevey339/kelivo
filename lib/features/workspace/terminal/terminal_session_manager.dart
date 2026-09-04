import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:terminal_view/core.dart';
import 'package:terminal_view/ui.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/terminal/osc_1337.dart';

typedef TerminalWakelockSetter = Future<void> Function(bool enable);

/// Interactive guest environment for in-app PTY sessions.
const Map<String, String> kTerminalGuestEnv = {
  'TERM': 'xterm-256color',
  'LANG': 'C.UTF-8',
  'HOME': '/root',
  'COLORTERM': 'truecolor',
};

const double kTerminalDefaultFontSize = 14;
const double kTerminalMinFontSize = 8;
const double kTerminalMaxFontSize = 28;

double clampTerminalFontSize(double value) =>
    value.clamp(kTerminalMinFontSize, kTerminalMaxFontSize);

/// Next unused default title for [requested] among [existing] titles.
///
/// The first session keeps [requested] (`demo`). Later ones are `demo 2`,
/// `demo 3`, … reusing the lowest free integer ≥ 2.
String uniqueTerminalSessionTitle({
  required String requested,
  required Iterable<String> existing,
}) {
  final used = existing.toSet();
  if (!used.contains(requested)) return requested;
  var n = 2;
  while (used.contains('$requested $n')) {
    n += 1;
  }
  return '$requested $n';
}

/// Theme-aware palette for [TerminalView].
///
/// Light mode uses dark ink on the page surface and a darkened ANSI set so
/// yellow/cyan stay readable on white. Dark mode keeps the stock look for
/// ANSI colors while still taking surface, selection, and cursor from [cs].
TerminalTheme buildTerminalViewTheme(ColorScheme cs) {
  final light = cs.brightness == Brightness.light;
  const stock = TerminalThemes.defaultTheme;
  final background = cs.surface;
  final foreground = light ? cs.onSurface : stock.foreground;
  final selection = cs.primary.withValues(alpha: light ? 0.28 : 0.40);
  final selectionForeground = _terminalSelectionForeground(cs, selection);

  Color ansi(Color color) {
    if (!light) return color;
    final hsl = HSLColor.fromColor(color);
    final target = hsl.lightness > 0.55
        ? (hsl.lightness * 0.40).clamp(0.22, 0.46)
        : (hsl.lightness * 0.72).clamp(0.22, 0.46);
    return hsl.withLightness(target).toColor();
  }

  return TerminalTheme(
    cursor: light ? cs.onSurface : stock.cursor,
    cursorAccent: background,
    selection: selection,
    selectionForeground: selectionForeground,
    foreground: foreground,
    background: background,
    black: light
        ? Color.lerp(const Color(0xFF1A1A1A), cs.onSurface, 0.25)!
        : stock.black,
    red: ansi(stock.red),
    green: ansi(stock.green),
    yellow: ansi(stock.yellow),
    blue: ansi(stock.blue),
    magenta: ansi(stock.magenta),
    cyan: ansi(stock.cyan),
    white: light ? Color.lerp(cs.onSurface, cs.surface, 0.28)! : stock.white,
    brightBlack: light
        ? Color.lerp(cs.onSurface, cs.surface, 0.42)!
        : stock.brightBlack,
    brightRed: ansi(stock.brightRed),
    brightGreen: ansi(stock.brightGreen),
    brightYellow: ansi(stock.brightYellow),
    brightBlue: ansi(stock.brightBlue),
    brightMagenta: ansi(stock.brightMagenta),
    brightCyan: ansi(stock.brightCyan),
    brightWhite: light ? cs.onSurface : stock.brightWhite,
    searchHitBackground: light
        ? cs.primary.withValues(alpha: 0.35)
        : stock.searchHitBackground,
    searchHitBackgroundCurrent: light
        ? cs.primary
        : stock.searchHitBackgroundCurrent,
    searchHitForeground: light ? cs.onPrimary : stock.searchHitForeground,
  );
}

Color _terminalSelectionForeground(ColorScheme cs, Color selection) {
  final onSelection = cs.onPrimary.computeLuminance();
  final onSurface = cs.onSurface.computeLuminance();
  final back = selection.computeLuminance();
  final onPrimaryContrast = (onSelection - back).abs();
  final onSurfaceContrast = (onSurface - back).abs();
  return onPrimaryContrast >= onSurfaceContrast ? cs.onPrimary : cs.onSurface;
}

/// One in-app terminal attached to a [PtySession].
class TerminalSession {
  TerminalSession({
    required this.id,
    required this.title,
    required this.terminal,
    required this.pty,
    required this.mounts,
    required this.cwd,
    required this.targetKey,
    this.hostDir,
    this.conversationId,
    this.workspaceId,
    this.fontSize = kTerminalDefaultFontSize,
    required this.onChanged,
    required StreamController<Uri> openUrlController,
  }) : _openUrls = openUrlController;

  final String id;
  String title;
  final Terminal terminal;
  final PtySession pty;
  final List<Mount> mounts;
  final String cwd;
  final String targetKey;
  final String? hostDir;
  final String? conversationId;
  final String? workspaceId;

  double fontSize;
  bool exited = false;
  int? exitCode;
  bool ctrlModifier = false;
  bool altModifier = false;

  final void Function() onChanged;
  final StreamController<Uri> _openUrls;
  StreamSubscription<Uint8List>? _outputSub;
  ByteConversionSink? _utf8Sink;
  bool _closed = false;

  bool get isClosed => _closed;

  /// True while the PTY process has not exited and this session is open.
  bool get isAlive => !exited && !_closed;

  Stream<Uri> get openUrlRequests => _openUrls.stream;

  void notify() => onChanged();

  void toggleCtrl() {
    ctrlModifier = !ctrlModifier;
    onChanged();
  }

  void toggleAlt() {
    altModifier = !altModifier;
    onChanged();
  }

  void clearModifiers() {
    if (!ctrlModifier && !altModifier) return;
    ctrlModifier = false;
    altModifier = false;
    onChanged();
  }

  /// Types [text] into the shell input line (no trailing newline).
  void appendInput(String text) {
    if (text.isEmpty || exited) return;
    terminal.textInput(text);
  }

  void sendText(String text) {
    if (text.isEmpty || exited) return;
    terminal.textInput(text);
  }

  void sendKey(TerminalKey key, {bool applyModifiers = true}) {
    if (exited) return;
    final ctrl = applyModifiers && ctrlModifier;
    final alt = applyModifiers && altModifier;
    terminal.keyInput(key, ctrl: ctrl, alt: alt);
    if (applyModifiers && (ctrlModifier || altModifier)) {
      clearModifiers();
    }
  }

  void pasteText(String text) {
    if (text.isEmpty || exited) return;
    terminal.paste(text);
  }

  void clearScreen() {
    terminal.eraseDisplay();
    terminal.eraseScrollbackOnly();
    terminal.setCursor(0, 0);
    terminal.notifyListeners();
  }

  void setFontSize(double value) {
    final next = clampTerminalFontSize(value);
    if (next == fontSize) return;
    fontSize = next;
    onChanged();
  }

  void _closeUtf8Sink() {
    final sink = _utf8Sink;
    if (sink == null) return;
    _utf8Sink = null;
    sink.close();
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await _outputSub?.cancel();
    _outputSub = null;
    _closeUtf8Sink();
    try {
      await pty.close();
    } catch (_) {}
    if (!_openUrls.isClosed) {
      await _openUrls.close();
    }
  }
}

/// Owns open [TerminalSession]s, PTY wiring, OSC 1337 handling, and wakelock.
class TerminalSessionManager extends ChangeNotifier {
  TerminalSessionManager({TerminalWakelockSetter? setWakelock})
    : _setWakelock = setWakelock ?? _pluginWakelock;

  final TerminalWakelockSetter _setWakelock;
  final List<TerminalSession> _sessions = <TerminalSession>[];
  bool _wakelockOn = false;
  bool _disposed = false;

  /// Font size applied to newly opened sessions. Updated by pinch-to-zoom.
  double defaultFontSize = kTerminalDefaultFontSize;

  List<TerminalSession> get sessions =>
      List<TerminalSession>.unmodifiable(_sessions);

  TerminalSession? byId(String id) {
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  /// Reuses a live session for the same conversation/workspace + cwd.
  TerminalSession? findReusable({
    String? conversationId,
    String? workspaceId,
    required String cwd,
  }) {
    final key = sessionTargetKey(
      conversationId: conversationId,
      workspaceId: workspaceId,
      cwd: cwd,
    );
    for (var i = _sessions.length - 1; i >= 0; i--) {
      final session = _sessions[i];
      if (!session.exited && session.targetKey == key) return session;
    }
    return null;
  }

  static String sessionTargetKey({
    String? conversationId,
    String? workspaceId,
    required String cwd,
  }) {
    if (conversationId != null && conversationId.isNotEmpty) {
      return 'conversation:$conversationId|$cwd';
    }
    if (workspaceId != null && workspaceId.isNotEmpty) {
      return 'workspace:$workspaceId|$cwd';
    }
    return 'cwd:$cwd';
  }

  Future<TerminalSession> open({
    required WorkspaceRuntime runtime,
    required List<Mount> mounts,
    required String cwd,
    String? title,
    String? initialCommand,
    String? hostDir,
    String? conversationId,
    String? workspaceId,
    int cols = 80,
    int rows = 24,
  }) async {
    final pty = await runtime.openPty(
      mounts: mounts,
      cwd: cwd,
      env: kTerminalGuestEnv,
      cols: cols,
      rows: rows,
    );
    final terminal = Terminal(
      maxLines: 10000,
      platform: defaultTargetPlatform == TargetPlatform.iOS
          ? TerminalTargetPlatform.ios
          : defaultTargetPlatform == TargetPlatform.android
          ? TerminalTargetPlatform.android
          : defaultTargetPlatform == TargetPlatform.macOS
          ? TerminalTargetPlatform.macos
          : defaultTargetPlatform == TargetPlatform.windows
          ? TerminalTargetPlatform.windows
          : defaultTargetPlatform == TargetPlatform.linux
          ? TerminalTargetPlatform.linux
          : TerminalTargetPlatform.unknown,
    );
    final rawTitle = (title != null && title.isNotEmpty)
        ? title
        : _basename(cwd);
    final resolvedTitle = uniqueTerminalSessionTitle(
      requested: rawTitle,
      existing: _sessions.map((session) => session.title),
    );
    final openUrls = StreamController<Uri>.broadcast();
    final session = TerminalSession(
      id: const Uuid().v4(),
      title: resolvedTitle,
      terminal: terminal,
      pty: pty,
      mounts: List<Mount>.unmodifiable(mounts),
      cwd: cwd,
      targetKey: sessionTargetKey(
        conversationId: conversationId,
        workspaceId: workspaceId,
        cwd: cwd,
      ),
      hostDir: hostDir,
      conversationId: conversationId,
      workspaceId: workspaceId,
      fontSize: clampTerminalFontSize(defaultFontSize),
      onChanged: notifyListeners,
      openUrlController: openUrls,
    );

    final interceptor = Osc1337Interceptor(
      onUrl: (uri) {
        if (!openUrls.isClosed) openUrls.add(uri);
      },
    );

    terminal.onOutput = (data) {
      final payload = _applyStickyModifiers(session, data);
      if (payload.isEmpty || session.exited) return;
      unawaited(pty.write(Uint8List.fromList(utf8.encode(payload))));
    };
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      unawaited(pty.resize(width, height));
    };

    session._utf8Sink = const Utf8Decoder(
      allowMalformed: true,
    ).startChunkedConversion(_TerminalWriteSink(terminal));
    session._outputSub = pty.output.listen(
      (bytes) {
        final filtered = interceptor.process(bytes);
        if (filtered.isEmpty) return;
        session._utf8Sink?.add(filtered);
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('Terminal PTY output error: $error\n$stack');
      },
      onDone: () {
        session._closeUtf8Sink();
        unawaited(_markExited(session, session.exitCode ?? 0));
      },
    );

    unawaited(
      pty.exitCode.then(
        (code) => _markExited(session, code),
        onError: (Object error, StackTrace stack) {
          debugPrint('Terminal PTY exit error: $error\n$stack');
          return _markExited(session, 1);
        },
      ),
    );

    _sessions.add(session);
    await _syncWakelock();
    notifyListeners();

    if (initialCommand != null && initialCommand.isNotEmpty) {
      session.appendInput(initialCommand);
    }
    return session;
  }

  Future<void> close(String id) async {
    final index = _sessions.indexWhere((session) => session.id == id);
    if (index < 0) return;
    final session = _sessions.removeAt(index);
    await session.dispose();
    await _syncWakelock();
    notifyListeners();
  }

  Future<void> closeAll() async {
    final snapshot = List<TerminalSession>.from(_sessions);
    _sessions.clear();
    for (final session in snapshot) {
      await session.dispose();
    }
    await _syncWakelock();
    notifyListeners();
  }

  void rename(String id, String title) {
    final session = byId(id);
    if (session == null) return;
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed == session.title) return;
    session.title = trimmed;
    notifyListeners();
  }

  void setFontSize(String id, double value) {
    final session = byId(id);
    final next = clampTerminalFontSize(value);
    defaultFontSize = next;
    if (session == null) {
      notifyListeners();
      return;
    }
    session.setFontSize(next);
  }

  Future<void> _markExited(TerminalSession session, int code) async {
    if (_disposed || session.isClosed || session.exited) return;
    session.exited = true;
    session.exitCode = code;
    session.terminal.write('\r\n\x1b[2m[process exited $code]\x1b[0m\r\n');
    notifyListeners();
  }

  String _applyStickyModifiers(TerminalSession session, String data) {
    var payload = data;
    if (session.ctrlModifier && data.length == 1) {
      final mapped = _controlChar(data.codeUnitAt(0));
      if (mapped != null) {
        payload = mapped;
        session.ctrlModifier = false;
        session.onChanged();
      }
    }
    if (session.altModifier && payload.length == 1) {
      final unit = payload.codeUnitAt(0);
      if (unit >= 32 && unit != 0x7f) {
        payload = '\x1b$payload';
        session.altModifier = false;
        session.onChanged();
      }
    }
    return payload;
  }

  static String? _controlChar(int unit) {
    if (unit >= 97 && unit <= 122) {
      return String.fromCharCode(unit - 96);
    }
    if (unit >= 64 && unit <= 95) {
      return String.fromCharCode(unit - 64);
    }
    return null;
  }

  Future<void> _syncWakelock() async {
    final should = _sessions.isNotEmpty;
    if (should == _wakelockOn) return;
    _wakelockOn = should;
    try {
      await _setWakelock(should);
    } catch (error, stack) {
      debugPrint('Terminal wakelock failed: $error\n$stack');
    }
  }

  static Future<void> _pluginWakelock(bool enable) async {
    if (enable) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i].isNotEmpty) return parts[i];
    }
    return path;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final session in List<TerminalSession>.from(_sessions)) {
      unawaited(session.dispose());
    }
    _sessions.clear();
    if (_wakelockOn) {
      _wakelockOn = false;
      unawaited(
        _setWakelock(false).catchError((Object error, StackTrace stack) {
          debugPrint('Terminal wakelock failed: $error\n$stack');
        }),
      );
    }
    super.dispose();
  }
}

class _TerminalWriteSink implements ChunkedConversionSink<String> {
  _TerminalWriteSink(this._terminal);

  final Terminal _terminal;

  @override
  void add(String chunk) {
    if (chunk.isEmpty) return;
    _terminal.write(chunk);
  }

  @override
  void close() {}
}
