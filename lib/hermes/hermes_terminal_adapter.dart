import 'dart:async';
import 'package:xterm/xterm.dart';
import 'hermes_event_bus.dart';
import 'hermes_gateway.dart';
import 'hermes_models.dart';

/// Bridges [HermesEventBus] terminal events to a [Terminal] instance.
///
/// Usage:
/// ```dart
/// final adapter = HermesTerminalAdapter(
///   eventBus: gatewayProvider.eventBus,
///   sessionId: sessionId,
///   gateway: gateway,
/// );
/// // Pass adapter.terminal to TerminalView widget
/// ```
class HermesTerminalAdapter {
  HermesTerminalAdapter({
    required HermesEventBus eventBus,
    required String sessionId,
    required HermesGateway gateway,
  })  : _eventBus = eventBus,
        _sessionId = sessionId,
        _gateway = gateway {
    _subscription = _eventBus.allEvents.listen(_onEvent);

    // Pipe user keystrokes to Hermes backend
    terminal.onOutput = _onTerminalOutput;
    // Pipe resize to Hermes backend
    terminal.onResize = _onTerminalResize;
  }

  final HermesEventBus _eventBus;
  final String _sessionId;
  final HermesGateway _gateway;
  StreamSubscription<HermesStreamEvent>? _subscription;

  /// The xterm Terminal instance to pass to [TerminalView].
  final Terminal terminal = Terminal(maxLines: 5000);

  bool _isClosed = false;

  void _onEvent(HermesStreamEvent event) {
    if (_isClosed) return;
    if (!_matchesSession(event)) return;

    if (event is TerminalOutput) {
      terminal.write(event.text);
    } else if (event is TerminalClosed) {
      terminal.write('\r\n[Process exited${event.exitCode != null ? ' with code ${event.exitCode}' : ''}]\r\n');
      _isClosed = true;
    }
  }

  void _onTerminalOutput(String data) {
    if (_isClosed || _sessionId.isEmpty) return;
    _gateway.terminalReadRespond(_sessionId, data);
  }

  void _onTerminalResize(
    int width,
    int height,
    int pixelWidth,
    int pixelHeight,
  ) {
    if (_sessionId.isEmpty) return;
    _gateway.terminalResize(_sessionId, width, height);
  }

  bool _matchesSession(HermesStreamEvent event) {
    if (event is TerminalOutput) return event.sessionId == _sessionId;
    if (event is TerminalReadRequest) return event.sessionId == _sessionId;
    if (event is TerminalClosed) return event.sessionId == _sessionId;
    return false;
  }

  /// Dispose this adapter and cancel subscriptions.
  void dispose() {
    _isClosed = true;
    _subscription?.cancel();
    terminal.onOutput = null;
    terminal.onResize = null;
  }
}
