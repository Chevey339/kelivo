import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../logger.dart';
import '../models/models.dart';
import 'event_source_stub.dart' as stub;

final Logger _logger = Logger('mcp_client.event_source_io');

/// Native platform EventSource implementation using HttpClient
class EventSource implements stub.EventSource {
  HttpClient? _client;
  HttpClientRequest? _request;
  HttpClientResponse? _response;
  StreamSubscription? _subscription;
  final _buffer = StringBuffer();
  bool _isConnected = false;

  EventSource();

  @override
  bool get isConnected => _isConnected;

  @override
  HttpClientResponse? get response => _response;

  @override
  Future<void> connect(
    String url, {
    Map<String, String>? headers,
    Function(String?)? onOpen,
    Function(dynamic)? onMessage,
    Function(dynamic)? onError,
    Function(String?)? onEndpoint,
  }) async {
    _logger.debug('EventSource connecting');
    if (_isConnected) {
      throw McpError('EventSource is already connected');
    }

    try {
      // Initialize connection
      _client = HttpClient();
      _request = await _client!.getUrl(Uri.parse(url));

      // Set up MCP standard SSE headers
      _request!.headers.set('Accept', 'text/event-stream');
      _request!.headers.set('Cache-Control', 'no-cache');
      _request!.headers.set(
        'Accept-Encoding',
        'identity',
      ); // Disable compression
      if (headers != null) {
        headers.forEach((key, value) {
          _request!.headers.set(key, value);
        });
      }

      _response = await _request!.close();

      if (_response!.statusCode != 200) {
        final body = await _response!.transform(utf8.decoder).join();
        throw McpError(
          'Failed to connect to SSE endpoint: ${_response!.statusCode} - $body',
        );
      }

      _isConnected = true;
      _logger.debug('EventSource connection established');

      // Set up subscription to process events with proper UTF-8 handling
      _subscription = _response!.listen(
        (List<int> data) {
          try {
            // Convert bytes to string using UTF-8 decoder
            final chunk = utf8.decode(data, allowMalformed: true);
            // Log raw data for debugging
            _logger.debug('Raw SSE data: [$chunk]');
            _buffer.write(chunk);

            // Process all events in buffer
            final content = _buffer.toString();

            // Simple check for JSON-RPC responses
            if (content.contains('"jsonrpc":"2.0"') ||
                content.contains('"jsonrpc": "2.0"')) {
              _logger.debug('Detected JSON-RPC data in SSE stream');

              try {
                // Try to extract JSON objects from the stream
                final jsonStart = content.indexOf('{');
                final jsonEnd = content.lastIndexOf('}') + 1;

                if (jsonStart >= 0 && jsonEnd > jsonStart) {
                  final jsonStr = content.substring(jsonStart, jsonEnd);
                  _logger.debug('Extracted JSON: $jsonStr');

                  try {
                    final jsonData = jsonDecode(jsonStr);
                    _logger.debug('Parsed JSON-RPC data: $jsonData');

                    // Clear the processed part from buffer
                    if (jsonEnd < content.length) {
                      _buffer.clear();
                      _buffer.write(content.substring(jsonEnd));
                    } else {
                      _buffer.clear();
                    }

                    // Forward to message handler
                    if (onMessage != null) {
                      onMessage(jsonData);
                    }
                    return; // Processed JSON data
                  } catch (e) {
                    _logger.debug('JSON parse error: $e');
                  }
                }
              } catch (e) {
                _logger.debug('Error extracting JSON: $e');
              }
            }

            // Process SSE events
            final event = _processBuffer();
            _logger.debug(
              'Processed SSE event: ${event.event}, data: ${event.data}',
            );

            if (event.event == 'endpoint' && event.data != null) {
              _logger.debug('Received endpoint event: ${event.data}');
              if (onEndpoint != null) {
                onEndpoint(event.data);
              }
            } else if (event.event == 'open' && onOpen != null) {
              _logger.debug('Connection opened');
              onOpen(event.data);
            } else if (event.event == 'message' && event.data != null) {
              _logger.debug('Received message data: ${event.data}');
              // Try to parse as JSON
              try {
                final message = jsonDecode(event.data!);
                _logger.debug('Parsed message: $message');
                if (onMessage != null) {
                  onMessage(message);
                }
              } catch (e) {
                _logger.debug('Failed to parse message as JSON: $e');
                // Pass raw data if JSON parsing fails
                if (onMessage != null) {
                  onMessage(event.data);
                }
              }
            } else if (event.event == 'error' && event.data != null) {
              _logger.error('Received error event: ${event.data}');
              if (onError != null) {
                onError(event.data);
              }
            } else if (event.event == null && event.data != null) {
              // Handle data without explicit event type
              _logger.debug('Received data without event type: ${event.data}');

              // Check if it's an endpoint URL
              if (event.data!.startsWith('http://') ||
                  event.data!.startsWith('https://')) {
                _logger.debug('Detected endpoint URL: ${event.data}');
                if (onEndpoint != null) {
                  onEndpoint(event.data);
                }
              } else {
                // Treat as regular message
                if (onMessage != null) {
                  onMessage(event.data);
                }
              }
            }
          } catch (e) {
            _logger.error('Error processing SSE data: $e');
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

  /// Process the buffer to extract SSE events
  SseEvent _processBuffer() {
    final content = _buffer.toString();
    final lines = content.split('\n');

    String? eventType;
    String? eventData;
    String? eventId;
    final completeLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check if we've reached the end of an event (empty line)
      if (line.isEmpty || line == '\r') {
        if (eventType != null || eventData != null) {
          // We have a complete event
          _buffer.clear();
          // Add remaining lines back to buffer
          for (int j = i + 1; j < lines.length; j++) {
            if (j < lines.length - 1) {
              _buffer.writeln(lines[j]);
            } else {
              _buffer.write(lines[j]);
            }
          }
          return SseEvent(event: eventType, data: eventData, id: eventId);
        }
        continue;
      }

      // Parse event fields
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        final data = line.substring(5).trim();
        if (eventData == null) {
          eventData = data;
        } else {
          eventData = '$eventData\n$data';
        }
      } else if (line.startsWith('id:')) {
        eventId = line.substring(3).trim();
      } else if (line.startsWith(':')) {
        // Comment line, ignore
      } else {
        // Unknown line format
        completeLines.add(line);
      }
    }

    // No complete event found
    return SseEvent(event: null, data: null, id: null);
  }

  @override
  void close() {
    _logger.debug('Closing EventSource');
    _isConnected = false;
    _subscription?.cancel();
    _client?.close(force: true);
  }
}

/// SSE event data
class SseEvent {
  final String? event;
  final String? data;
  final String? id;

  SseEvent({this.event, this.data, this.id});
}
