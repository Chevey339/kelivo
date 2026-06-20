import 'dart:async';
import 'hermes_models.dart';

/// Lightweight event bus for Hermes stream events.
///
/// All events parsed from the WS connection flow through here so
/// Provider-layer consumers can subscribe to specific event types
/// without coupling to the gateway.
class HermesEventBus {
  final _controller = StreamController<HermesStreamEvent>.broadcast();

  /// Broadcast stream of all incoming Hermes events.
  Stream<HermesStreamEvent> get allEvents => _controller.stream;

  /// Subscribe to events of type [T].
  Stream<T> eventsOf<T extends HermesStreamEvent>() {
    return allEvents.where((e) => e is T).cast<T>();
  }

  /// Emit a parsed event into the bus.
  void emit(HermesStreamEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Dispose the bus and release resources.
  void dispose() {
    _controller.close();
  }
}
