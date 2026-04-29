import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../providers/terminal_ai_tool_provider.dart';
import '../services/terminal_native_bridge.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key, TerminalNativeBridge? bridge})
    : _bridge = bridge;

  final TerminalNativeBridge? _bridge;

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  late final TerminalNativeBridge _bridge =
      widget._bridge ?? TerminalNativeBridge();
  final Uuid _uuid = const Uuid();
  late final TerminalController _terminalController = TerminalController();
  late final StreamController<List<int>> _outputBytesController;
  late final StreamSubscription<String> _outputTextSubscription;
  final List<String> _pendingTerminalWrites = <String>[];
  Timer? _eventsPollTimer;
  Timer? _terminalWriteTimer;
  late Terminal _terminal = _createTerminal();
  String _sessionId = '';
  String? _errorCode;
  bool _connecting = true;
  bool _sessionActive = false;
  bool _pollingEvents = false;
  int _startGeneration = 0;
  int _idlePollsBeforeFirstOutput = 0;
  int _drainedOutputEvents = 0;
  int _drainedOutputBytes = 0;
  int _terminalWriteChars = 0;
  bool _loggedFirstOutputEvent = false;
  bool _loggedFirstTerminalWrite = false;

  static const _kernelBootingCode = 'terminal_kernel_booting';
  static const _kernelBootRetryDelay = Duration(milliseconds: 350);
  static const _kernelBootMaxAttempts = 60;
  static const _eventPollInterval = Duration(milliseconds: 100);
  static const _terminalWriteInterval = Duration(milliseconds: 16);
  static const _maxTerminalWriteCharsPerFrame = 8192;

  @override
  void initState() {
    super.initState();
    _outputBytesController = StreamController<List<int>>();
    _outputTextSubscription = _outputBytesController.stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((text) {
          if (text.isEmpty) return;
          _enqueueTerminalWrite(text);
        });
    _bridge.appendDiagnostic('TerminalPage initState').ignore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bridge.appendDiagnostic('TerminalPage postFrame start').ignore();
      _start();
    });
  }

  @override
  void dispose() {
    _startGeneration++;
    _bridge.appendDiagnostic('TerminalPage dispose').ignore();
    _eventsPollTimer?.cancel();
    _terminalWriteTimer?.cancel();
    if (_sessionId.isNotEmpty) {
      _bridge.stopSession(sessionId: _sessionId).ignore();
    }
    _outputTextSubscription.cancel().ignore();
    _outputBytesController.close().ignore();
    super.dispose();
  }

  Future<void> _start() async {
    final generation = ++_startGeneration;
    final previousSessionId = _sessionId;
    if (previousSessionId.isNotEmpty) {
      await _bridge
          .stopSession(sessionId: previousSessionId)
          .catchError((_) {});
    }
    _sessionId = _uuid.v4();
    _sessionActive = false;
    _idlePollsBeforeFirstOutput = 0;
    _drainedOutputEvents = 0;
    _drainedOutputBytes = 0;
    _terminalWriteChars = 0;
    _loggedFirstOutputEvent = false;
    _loggedFirstTerminalWrite = false;
    _pendingTerminalWrites.clear();
    _terminal = _createTerminal();
    await _startWithRetry(generation: generation, attempt: 0);
  }

  Terminal _createTerminal() {
    return Terminal(
      maxLines: 5000,
      onOutput: _handleTerminalInput,
      onResize: _handleTerminalResize,
    );
  }

  Future<void> _startWithRetry({
    required int generation,
    required int attempt,
  }) async {
    if (!mounted || generation != _startGeneration) return;
    setState(() {
      _connecting = true;
      _errorCode = null;
    });
    try {
      await _bridge.appendDiagnostic(
        'TerminalPage startSession attempt=$attempt',
      );
      await _bridge.startSession(sessionId: _sessionId, cols: 80, rows: 24);
      _sessionActive = true;
      if (mounted && generation == _startGeneration) {
        setState(() {
          _connecting = false;
          _errorCode = null;
        });
      }
      await _bridge.appendDiagnostic('TerminalPage startSession success');
      _ensureEventPolling();
    } on TerminalNativeBridgeException catch (error) {
      if (!mounted) return;
      await _bridge.appendDiagnostic(
        'TerminalPage startSession error=${error.code} attempt=$attempt',
      );
      _sessionActive = false;
      if (error.code == _kernelBootingCode &&
          attempt < _kernelBootMaxAttempts) {
        await Future<void>.delayed(_kernelBootRetryDelay);
        return _startWithRetry(generation: generation, attempt: attempt + 1);
      }
      if (generation != _startGeneration) return;
      setState(() => _errorCode = error.code);
    } finally {
      if (mounted && generation == _startGeneration) {
        setState(() => _connecting = false);
      }
    }
  }

  void _ensureEventPolling() {
    if (_eventsPollTimer != null) return;
    _bridge.appendDiagnostic('TerminalPage event polling started').ignore();
    _eventsPollTimer = Timer.periodic(_eventPollInterval, (_) {
      _pollEvents();
    });
    _pollEvents();
  }

  Future<void> _pollEvents() async {
    if (_pollingEvents) return;
    _pollingEvents = true;
    try {
      final events = await _bridge.drainEvents();
      if (events.isEmpty && _sessionActive && !_loggedFirstOutputEvent) {
        _idlePollsBeforeFirstOutput++;
        if (_idlePollsBeforeFirstOutput == 20 ||
            _idlePollsBeforeFirstOutput == 50) {
          await _bridge.appendDiagnostic(
            'TerminalPage poll idle before first output polls=$_idlePollsBeforeFirstOutput',
          );
        }
      }
      if (events.length > 100) {
        await _bridge.appendDiagnostic(
          'TerminalPage drained many events count=${events.length}',
        );
      }
      for (final event in events) {
        _handleTerminalEvent(event);
      }
    } on TerminalNativeBridgeException catch (error) {
      await _bridge.appendDiagnostic(
        'TerminalPage drainEvents error=${error.code}',
      );
      if (!mounted) return;
      setState(() => _errorCode = error.code);
    } finally {
      _pollingEvents = false;
    }
  }

  void _handleTerminalEvent(Map<Object?, Object?> event) {
    final type = event['type']?.toString();
    final eventSessionId = event['sessionId']?.toString();
    if (eventSessionId != null && eventSessionId != _sessionId) return;
    if (type == 'sessionStarted') {
      if (!mounted) return;
      setState(() {
        _sessionActive = true;
        _errorCode = null;
      });
    } else if (type == 'sessionOutput') {
      final dataBase64 = event['dataBase64']?.toString();
      if (dataBase64 != null && dataBase64.isNotEmpty) {
        final bytes = base64Decode(dataBase64);
        _recordOutputEvent(bytes.length);
        _outputBytesController.add(bytes);
        return;
      }
      final text = event['data']?.toString();
      if (text == null || text.isEmpty) return;
      _recordOutputEvent(utf8.encode(text).length);
      _enqueueTerminalWrite(text);
    } else if (type == 'sessionExit') {
      if (!mounted) return;
      setState(() {
        _sessionActive = false;
        _errorCode = event['code']?.toString() ?? 'session_exit';
      });
    } else if (type == 'sessionError') {
      if (!mounted) return;
      setState(() {
        _sessionActive = false;
        _errorCode = event['code']?.toString() ?? 'session_error';
      });
    }
  }

  void _enqueueTerminalWrite(String text) {
    _terminalWriteChars += text.length;
    if (!_loggedFirstTerminalWrite) {
      _loggedFirstTerminalWrite = true;
      _bridge
          .appendDiagnostic(
            'TerminalPage first terminal write chars=${text.length} totalChars=$_terminalWriteChars',
          )
          .ignore();
    }
    _pendingTerminalWrites.add(text);
    _terminalWriteTimer ??= Timer.periodic(_terminalWriteInterval, (_) {
      _flushTerminalWrites();
    });
  }

  void _flushTerminalWrites() {
    if (_pendingTerminalWrites.isEmpty) {
      _terminalWriteTimer?.cancel();
      _terminalWriteTimer = null;
      return;
    }
    var remaining = _maxTerminalWriteCharsPerFrame;
    final buffer = StringBuffer();
    while (_pendingTerminalWrites.isNotEmpty && remaining > 0) {
      final next = _pendingTerminalWrites.removeAt(0);
      if (next.length <= remaining) {
        buffer.write(next);
        remaining -= next.length;
      } else {
        buffer.write(next.substring(0, remaining));
        _pendingTerminalWrites.insert(0, next.substring(remaining));
        remaining = 0;
      }
    }
    final chunk = buffer.toString();
    if (chunk.isNotEmpty) {
      _terminal.write(chunk);
    }
  }

  void _recordOutputEvent(int bytes) {
    _drainedOutputEvents++;
    _drainedOutputBytes += bytes;
    if (!_loggedFirstOutputEvent) {
      _loggedFirstOutputEvent = true;
      _bridge
          .appendDiagnostic(
            'TerminalPage first output event bytes=$bytes totalEvents=$_drainedOutputEvents totalBytes=$_drainedOutputBytes',
          )
          .ignore();
    } else if (_drainedOutputEvents == 10 || _drainedOutputEvents == 50) {
      _bridge
          .appendDiagnostic(
            'TerminalPage output summary events=$_drainedOutputEvents bytes=$_drainedOutputBytes',
          )
          .ignore();
    }
  }

  Future<void> _sendShortcut(String data) async {
    if (!_sessionActive) return;
    try {
      await _bridge.writeSession(sessionId: _sessionId, data: data);
    } on TerminalNativeBridgeException catch (error) {
      if (!mounted) return;
      setState(() => _errorCode = error.code);
    }
  }

  void _handleTerminalInput(String data) {
    if (!_sessionActive) return;
    _bridge.writeSession(sessionId: _sessionId, data: data).catchError((error) {
      if (error is! TerminalNativeBridgeException || !mounted) {
        return;
      }
      setState(() => _errorCode = error.code);
    });
  }

  void _handleTerminalResize(
    int cols,
    int rows,
    int pixelWidth,
    int pixelHeight,
  ) {
    if (!_sessionActive) return;
    _bridge
        .resizeSession(sessionId: _sessionId, cols: cols, rows: rows)
        .catchError((error) {
          if (error is! TerminalNativeBridgeException || !mounted) {
            return;
          }
          setState(() => _errorCode = error.code);
        });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final shortcuts = [
      (l10n.terminalShortcutEsc, '\x1b'),
      (l10n.terminalShortcutTab, '\t'),
      (l10n.terminalShortcutCtrl, '\x03'),
      (l10n.terminalShortcutSlash, '/'),
      (l10n.terminalShortcutDash, '-'),
      (l10n.terminalShortcutPipe, '|'),
      (l10n.terminalShortcutTilde, '~'),
      (l10n.terminalShortcutLeft, '\x1b[D'),
      (l10n.terminalShortcutUp, '\x1b[A'),
      (l10n.terminalShortcutDown, '\x1b[B'),
      (l10n.terminalShortcutRight, '\x1b[C'),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.terminalPageTitle),
        actions: [
          Tooltip(
            message: l10n.terminalPageRestartTooltip,
            child: IosIconButton(icon: Lucide.RefreshCw, onTap: _start),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _connecting
                        ? l10n.terminalPageConnecting
                        : _errorCode == null
                        ? l10n.terminalPageConnected
                        : l10n.terminalPageConnectionFailed(_errorCode!),
                    style: TextStyle(
                      fontSize: 13,
                      color: _errorCode == null ? cs.primary : cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Selector<TerminalAiToolProvider, bool>(
                  selector: (_, provider) => provider.enabled,
                  builder: (context, enabled, _) {
                    final provider = context.read<TerminalAiToolProvider>();
                    final available =
                        TerminalAiToolProvider.isAvailableOnCurrentPlatform();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.terminalPageAiTools,
                          style: TextStyle(
                            fontSize: 13,
                            color: available
                                ? cs.onSurfaceVariant
                                : cs.onSurfaceVariant.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IosSwitch(
                          value: available && enabled,
                          onChanged: available
                              ? (value) => provider.setEnabled(value).ignore()
                              : null,
                          semanticLabel: l10n.terminalPageAiTools,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  TerminalView(
                    _terminal,
                    controller: _terminalController,
                    autofocus: true,
                    deleteDetection: true,
                    backgroundOpacity: 1,
                    keyboardType: TextInputType.visiblePassword,
                    keyboardAppearance: Brightness.dark,
                    theme: TerminalThemes.whiteOnBlack,
                    textStyle: const TerminalStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (_connecting || _errorCode != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              _connecting
                                  ? l10n.terminalPageWaitingForOutput
                                  : l10n.terminalPageRuntimeUnavailable,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 13,
                                height: 1.35,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  for (final shortcut in shortcuts)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ShortcutKey(
                        label: shortcut.$1,
                        onTap: () => _sendShortcut(shortcut.$2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutKey extends StatelessWidget {
  const _ShortcutKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
