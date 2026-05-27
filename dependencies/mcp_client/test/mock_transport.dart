import 'dart:async';

import 'package:mcp_client/src/models/models.dart';
import 'package:mcp_client/src/transport/transport.dart';

/// Mock transport for testing MCP client without using actual I/O
class MockTransport implements ClientTransport {
  final _messageController = StreamController<dynamic>.broadcast();
  final _closeCompleter = Completer<void>();
  final _responseQueue = <Map<String, dynamic>>[];
  final sentMessages = <Map<String, dynamic>>[];
  bool _closed = false;

  /// Optional callback for custom send handling
  void Function(dynamic)? onSend;

  /// Queue a response to be sent when a request is received
  void queueResponse(Map<String, dynamic> response) {
    _responseQueue.add(response);
  }

  /// Send a mock notification to the client
  void sendMockNotification(Map<String, dynamic> notification) {
    if (!_closed) {
      _messageController.add(notification);
    }
  }

  /// Simulate a server-initiated message arriving at the client. Use for
  /// inbound `sampling/createMessage`, `roots/list`, `elicitation/create`
  /// requests and any spec notification the test wants to inject.
  void simulateMessage(Map<String, dynamic> message) {
    if (!_closed) {
      _messageController.add(message);
    }
  }

  @override
  Stream<dynamic> get onMessage => _messageController.stream;

  @override
  Future<void> get onClose => _closeCompleter.future;

  @override
  void send(dynamic message) {
    if (_closed) {
      throw McpError('Transport is closed');
    }

    // Call custom handler if provided
    if (onSend != null) {
      onSend!(message);
    }

    // Store the sent message for later inspection
    if (message is Map<String, dynamic>) {
      sentMessages.add(message);

      // If this is a request, send a response if available
      if (message['method'] != null && message['id'] != null) {
        if (_responseQueue.isNotEmpty) {
          final response = _responseQueue.removeAt(0);

          // Ensure the response has the same ID as the request
          response['id'] = message['id'];

          // Send the response back to the client
          _scheduleResponse(response);
        }
      }
    }
  }

  /// Schedule a response to be sent asynchronously
  void _scheduleResponse(Map<String, dynamic> response) {
    // Send the response asynchronously to better simulate real-world behavior
    Future.microtask(() {
      if (!_closed && !_messageController.isClosed) {
        _messageController.add(response);
      }
    });
  }

  @override
  void close() {
    _closed = true;
    if (!_messageController.isClosed) {
      _messageController.close();
    }
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
  }
}
