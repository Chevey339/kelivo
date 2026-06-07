import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../logger.dart';
import '../models/models.dart';
import 'event_source_stub.dart' as stub;

final Logger _logger = Logger('mcp_client.event_source_web');

/// Web platform EventSource implementation using package:http
class EventSource implements stub.EventSource {
  http.Client? _client;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  http.StreamedResponse? _response;
  final _buffer = StringBuffer();

  EventSource();

  @override
  bool get isConnected => _isConnected;

  @override
  dynamic get response => _response;

  @override
  Future<void> connect(
    String url, {
    Map<String, String>? headers,
    Function(String?)? onOpen,
    Function(dynamic)? onMessage,
    Function(dynamic)? onError,
    Function(String?)? onEndpoint,
  }) async {
    _logger.debug('EventSource connecting (web)');
    if (_isConnected) {
      throw McpError('EventSource is already connected');
    }

    try {
      // Create headers map with SSE-specific headers
      final sseHeaders = <String, String>{
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        ...?headers,
      };

      // Create HTTP client
      _client = http.Client();

      // Create streaming request
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(sseHeaders);

      // Send request and get streamed response
      _response = await _client!.send(request);

      if (_response!.statusCode != 200) {
        final body = await _response!.stream.transform(utf8.decoder).join();
        throw McpError(
          'Failed to connect to SSE endpoint: ${_response!.statusCode} - $body',
        );
      }

      _isConnected = true;
      _logger.debug('EventSource connection established (web)');
      if (onOpen != null) {
        onOpen(null);
      }

      // Listen to the stream
      _subscription = _response!.stream
          .transform(utf8.decoder)
          .listen(
            (String chunk) {
              try {
                _logger.debug('Received SSE chunk: $chunk');
                _buffer.write(chunk);
                _processBuffer(onMessage, onEndpoint, onError);
              } catch (e) {
                _logger.error('Error processing SSE chunk: $e');
                if (onError != null) {
                  onError(e);
                }
              }
            },
            onError: (error) {
              _logger.error('EventSource stream error: $error');
              _isConnected = false;
              if (onError != null) {
                onError(error);
              }
            },
            onDone: () {
              _logger.debug('EventSource stream closed');
              _isConnected = false;
            },
          );
    } catch (e) {
      _logger.error('Failed to connect EventSource: $e');
      _isConnected = false;
      if (onError != null) {
        onError(e);
      }
      rethrow;
    }
  }

  void _processBuffer(
    Function(dynamic)? onMessage,
    Function(String?)? onEndpoint,
    Function(dynamic)? onError,
  ) {
    final content = _buffer.toString();

    // Process all complete events (separated by double newline)
    final eventBlocks = content.split(RegExp(r'(\r?\n){2}'));

    if (eventBlocks.length < 2) {
      // No complete event yet
      return;
    }

    // Process complete events
    for (int i = 0; i < eventBlocks.length - 1; i++) {
      final eventBlock = eventBlocks[i];
      if (eventBlock.isEmpty) continue;

      final lines = eventBlock.split(RegExp(r'\r?\n'));
      String? eventType;
      String? eventData;

      for (final line in lines) {
        if (line.startsWith('event:')) {
          eventType = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          if (eventData == null) {
            eventData = data;
          } else {
            eventData = '$eventData\n$data';
          }
        }
      }

      // Handle different event types
      if (eventType == 'endpoint' && eventData != null) {
        _logger.debug('Received endpoint event: $eventData');
        if (onEndpoint != null) {
          onEndpoint(eventData);
        }
      } else if ((eventType == 'message' || eventType == null) &&
          eventData != null) {
        _logger.debug('Received message data: $eventData');

        // Check if it's an endpoint URL without event type
        if (eventType == null &&
            (eventData.startsWith('http://') ||
                eventData.startsWith('https://'))) {
          _logger.debug('Detected endpoint URL: $eventData');
          if (onEndpoint != null) {
            onEndpoint(eventData);
          }
        } else if (eventData.contains('"jsonrpc":"2.0"') ||
            eventData.contains('"jsonrpc": "2.0"')) {
          // Check if it's JSON-RPC data
          try {
            final jsonData = jsonDecode(eventData);
            _logger.debug('Parsed JSON-RPC data: $jsonData');
            if (onMessage != null) {
              onMessage(jsonData);
            }
          } catch (e) {
            _logger.debug('Failed to parse as JSON-RPC: $e');
            if (onMessage != null) {
              onMessage(eventData);
            }
          }
        } else {
          // Try to parse as JSON
          try {
            final message = jsonDecode(eventData);
            _logger.debug('Parsed message: $message');
            if (onMessage != null) {
              onMessage(message);
            }
          } catch (e) {
            _logger.debug('Failed to parse message as JSON: $e');
            // Pass raw data if JSON parsing fails
            if (onMessage != null) {
              onMessage(eventData);
            }
          }
        }
      } else if (eventType == 'error' && eventData != null) {
        _logger.error('Received error event: $eventData');
        if (onError != null) {
          onError(eventData);
        }
      }
    }

    // Keep the incomplete last block in buffer
    _buffer.clear();
    if (eventBlocks.isNotEmpty) {
      _buffer.write(eventBlocks.last);
    }
  }

  @override
  void close() {
    _logger.debug('Closing EventSource (web)');
    _isConnected = false;
    _subscription?.cancel();
    _client?.close();
  }
}
