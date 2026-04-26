import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Process, HttpClient, ContentType;

import '../../logger.dart';
import '../models/models.dart';
import 'event_source.dart';
import 'stdio_launch.dart';

final Logger _logger = Logger('mcp_client.transport');

/// Abstract base class for client transport implementations
abstract class ClientTransport {
  /// Stream of incoming messages
  Stream<dynamic> get onMessage;

  /// Future that completes when the transport is closed
  Future<void> get onClose;

  /// Send a message through the transport
  void send(dynamic message);

  /// Close the transport
  void close();
}

/// Transport implementation using standard input/output streams
class StdioClientTransport implements ClientTransport {
  final Process _process;
  final _messageController = StreamController<dynamic>.broadcast();
  final List<StreamSubscription> _processSubscriptions = [];
  final _closeCompleter = Completer<void>();

  // Message queue for synchronized sending
  final _messageQueue = Queue<String>();
  bool _isSending = false;

  StdioClientTransport._internal(this._process) {
    _initialize();
  }

  /// Create a new STDIO transport by spawning a process
  static Future<StdioClientTransport> create({
    required String command,
    List<String> arguments = const [],
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    _logger.debug('Starting process: $command ${arguments.join(' ')}');

    final launchPlan = resolveStdioLaunch(command, arguments);
    final effectiveArgs = launchPlan.effectiveArgs;
    final executableCommand = launchPlan.executableCommand;

    _logger.debug(
      'Effective command: $executableCommand, args: $effectiveArgs',
    );

    final process = await Process.start(
      executableCommand,
      effectiveArgs,
      workingDirectory: workingDirectory,
      environment: environment,
    );

    return StdioClientTransport._internal(process);
  }

  void _initialize() {
    _logger.debug('Initializing STDIO transport');

    // Process stdout stream and handle messages
    var stdoutSubscription = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.isNotEmpty)
        .map((line) {
          try {
            _logger.debug('Raw received line: $line');
            final parsedMessage = jsonDecode(line);
            _logger.debug('Parsed message: $parsedMessage');
            return parsedMessage;
          } catch (e) {
            _logger.debug('JSON parsing error: $e');
            _logger.debug('Problematic line: $line');
            return null;
          }
        })
        .where((message) => message != null)
        .listen(
          (message) {
            _logger.debug('Processing message: $message');
            if (!_messageController.isClosed) {
              _messageController.add(message);
            }
          },
          onError: (error) {
            _logger.debug('Stream error: $error');
            _handleTransportError(error);
          },
          onDone: () {
            _logger.debug('stdout stream done');
            _handleStreamClosure();
          },
          cancelOnError: false,
        );

    // Store subscription for cleanup
    _processSubscriptions.add(stdoutSubscription);

    // Log stderr output
    var stderrSubscription = _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          _logger.debug('Server stderr: $line');
        });

    _processSubscriptions.add(stderrSubscription);

    // Handle process exit
    _process.exitCode.then((exitCode) {
      _logger.debug('Process exited with code: $exitCode');
      _handleStreamClosure();
    });
  }

  void _handleTransportError(dynamic error) {
    _logger.debug('Transport error: $error');
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.completeError(error);
    }
    _cleanup();
  }

  void _handleStreamClosure() {
    _logger.debug('Handling stream closure');
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
    _cleanup();
  }

  void _cleanup() {
    // Cancel all subscriptions
    for (var subscription in _processSubscriptions) {
      subscription.cancel();
    }
    _processSubscriptions.clear();

    if (!_messageController.isClosed) {
      _messageController.close();
    }

    // Ensure the process is terminated
    try {
      _process.kill();
    } catch (e) {
      // Process might already be terminated
      _logger.debug('Error killing process: $e');
    }
  }

  @override
  Stream<dynamic> get onMessage => _messageController.stream;

  @override
  Future<void> get onClose => _closeCompleter.future;

  // Add message to queue and process it
  @override
  void send(dynamic message) {
    try {
      final jsonMessage = jsonEncode(message);
      _logger.debug('Queueing message: $jsonMessage');

      // Add message to queue
      _messageQueue.add(jsonMessage);

      // Start processing queue if not already doing so
      _processMessageQueue();
    } catch (e) {
      _logger.debug('Error encoding message: $e');
      _logger.debug('Original message: $message');
      rethrow;
    }
  }

  // Process messages in queue one at a time
  void _processMessageQueue() {
    if (_isSending || _messageQueue.isEmpty) {
      return;
    }

    _isSending = true;

    // Process all messages in queue
    _sendNextMessage();
  }

  void _sendNextMessage() {
    if (_messageQueue.isEmpty) {
      _isSending = false;
      return;
    }

    final message = _messageQueue.removeFirst();

    try {
      _logger.debug('Sending message: $message');
      _process.stdin.writeln(message);

      // Use Timer to give stdin a chance to process
      Timer(Duration(milliseconds: 10), () {
        _logger.debug('Message sent successfully');
        _sendNextMessage();
      });
    } catch (e) {
      _logger.debug('Error sending message: $e');
      _isSending = false;
      throw Exception('Failed to write to process stdin: $e');
    }
  }

  @override
  void close() {
    _logger.debug('Closing StdioClientTransport');
    _cleanup();
  }
}

/// Transport implementation using Server-Sent Events (SSE) over HTTP
class SseClientTransport implements ClientTransport {
  final String serverUrl;
  final Map<String, String>? headers;
  final _messageController = StreamController<dynamic>.broadcast();
  final _closeCompleter = Completer<void>();
  final EventSource _eventSource = EventSource();
  String? _messageEndpoint;
  StreamSubscription? _subscription;
  bool _isClosed = false;

  // Private constructor
  SseClientTransport._internal({required this.serverUrl, this.headers});

  // Factory method for creation
  static Future<SseClientTransport> create({
    required String serverUrl,
    Map<String, String>? headers,
  }) async {
    final transport = SseClientTransport._internal(
      serverUrl: serverUrl,
      headers: headers,
    );

    try {
      // Generate session ID for MCP standard compliance
      final sessionId = _generateSessionId();
      final sseUrlWithSession =
          serverUrl.contains('?')
              ? '$serverUrl&session_id=$sessionId'
              : '$serverUrl?session_id=$sessionId';

      _logger.debug('SSE URL with session: $sseUrlWithSession');

      // Set up event handlers
      final endpointCompleter = Completer<String>();

      await transport._eventSource.connect(
        sseUrlWithSession,
        headers: headers,
        onMessage: (data) {
          // This is crucial - forward messages to the controller
          if (data is Map &&
              data.containsKey('jsonrpc') &&
              data.containsKey('id') &&
              !transport._messageController.isClosed) {
            _logger.debug('Forwarding JSON-RPC response: $data');
            transport._messageController.add(data);
          } else if (!transport._messageController.isClosed) {
            transport._messageController.add(data);
          }
        },
        onError: (e) {
          _logger.debug('SSE error: $e');
          if (!endpointCompleter.isCompleted) {
            endpointCompleter.completeError(e);
          }
          transport._handleError(e);
        },
        onEndpoint: (endpoint) {
          _logger.debug('Received endpoint from SSE: $endpoint');
          if (!endpointCompleter.isCompleted && endpoint != null) {
            endpointCompleter.complete(endpoint);
          }
        },
      );

      // Wait for endpoint
      final endpointPath = await endpointCompleter.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => throw McpError('Timed out waiting for endpoint'),
      );

      // Set up message endpoint following MCP standard
      transport._messageEndpoint =
          endpointPath.startsWith('http')
              ? endpointPath
              : transport._constructEndpointUrl(
                Uri.parse(serverUrl),
                endpointPath,
              );
      _logger.debug(
        'Transport ready with MCP standard endpoint: ${transport._messageEndpoint}',
      );

      return transport;
    } catch (e) {
      transport.close();
      throw McpError('Failed to establish SSE connection: $e');
    }
  }

  // Helper method to construct endpoint URL
  String _constructEndpointUrl(Uri baseUrl, String endpointPath) {
    try {
      final Uri endpointUri;
      if (endpointPath.contains('?')) {
        final parts = endpointPath.split('?');
        endpointUri = Uri(
          path: parts[0],
          query: parts.length > 1 ? parts[1] : null,
        );
      } else {
        endpointUri = Uri(path: endpointPath);
      }

      return Uri(
        scheme: baseUrl.scheme,
        host: baseUrl.host,
        port: baseUrl.port,
        path: endpointUri.path,
        query: endpointUri.query,
      ).toString();
    } catch (e) {
      _logger.debug('Error parsing endpoint URL: $e');
      // Fallback to simple concatenation
      return '${baseUrl.origin}$endpointPath';
    }
  }

  void _handleError(dynamic error) {
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.completeError(error);
    }
  }

  // Standard interface methods
  @override
  Stream<dynamic> get onMessage => _messageController.stream;

  @override
  Future<void> get onClose => _closeCompleter.future;

  @override
  void send(dynamic message) async {
    if (_isClosed) {
      _logger.debug('Attempted to send on closed transport');
      return;
    }

    if (_messageEndpoint == null) {
      throw McpError(
        'Cannot send message: SSE connection not fully established',
      );
    }

    try {
      final jsonMessage = jsonEncode(message);
      _logger.debug('Sending message: $jsonMessage');

      final url = Uri.parse(_messageEndpoint!);
      final client = HttpClient();
      final request = await client.postUrl(url);

      // Set headers
      request.headers.contentType = ContentType.json;
      if (headers != null) {
        headers!.forEach((name, value) {
          request.headers.add(name, value);
        });
      }

      // Send the request
      request.write(jsonMessage);
      final response = await request.close();

      // Check for successful delivery (200 OK or 202 Accepted)
      if (response.statusCode == 200 || response.statusCode == 202) {
        final responseBody = await response.transform(utf8.decoder).join();
        _logger.debug(
          'Message delivery confirmation (${response.statusCode}): $responseBody',
        );
        // Don't forward this to message controller, actual response comes via SSE
      } else {
        final responseBody = await response.transform(utf8.decoder).join();
        _logger.debug('Error response: $responseBody');
        throw McpError('Error sending message: ${response.statusCode}');
      }

      // Close the HTTP client
      client.close();
      _logger.debug('Message sent successfully');
    } catch (e) {
      _logger.debug('Error sending message: $e');
      rethrow;
    }
  }

  @override
  void close() {
    if (_isClosed) return;
    _isClosed = true;

    _logger.debug('Closing SseClientTransport');
    _subscription?.cancel();
    _eventSource.close();
    if (!_messageController.isClosed) {
      _messageController.close();
    }
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
  }

  // Generate a session ID for MCP protocol
  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 100000).toString().padLeft(5, '0');
    return '${timestamp.toRadixString(16)}$random';
  }
}
