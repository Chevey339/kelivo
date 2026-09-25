import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:http/http.dart' as http;
import 'package:socks5_proxy/socks_client.dart' as socks;

import '../logging/log_redactor.dart';
import 'request_logger.dart';

Future<InternetAddress?> _resolveProxyAddress(String host) async {
  final parsed = InternetAddress.tryParse(host);
  if (parsed != null) return parsed;
  try {
    final list = await InternetAddress.lookup(host);
    return list.isNotEmpty ? list.first : null;
  } catch (_) {
    return null;
  }
}

Future<Uint8List> _readLimited(Stream<List<int>> stream, int maxBytes) async {
  final out = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (out.length >= maxBytes) continue;
    final remaining = maxBytes - out.length;
    if (chunk.length <= remaining) {
      out.add(chunk);
    } else if (remaining > 0) {
      out.add(chunk.sublist(0, remaining));
    }
  }
  return out.takeBytes();
}

ConnectionTask<Socket> _directConnection(Uri uri, SecurityContext? context) {
  if (uri.scheme == 'https') {
    final Future<SecureSocket> socket = SecureSocket.connect(
      uri.host,
      uri.port,
      context: context,
    );
    return ConnectionTask.fromSocket(
      socket,
      () async => (await socket).close(),
    );
  }
  final Future<Socket> socket = Socket.connect(uri.host, uri.port);
  return ConnectionTask.fromSocket(socket, () async => (await socket).close());
}

class NetworkProxyConfig {
  final bool enabled;
  final String type;
  final String host;
  final int port;
  final String? username;
  final String? password;

  const NetworkProxyConfig({
    required this.enabled,
    this.type = 'http',
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  bool get isValid => enabled && host.trim().isNotEmpty && port > 0;
}

/// Bodies past this are file uploads; the log records their size only.
const int _loggedBodyLimit = 4 * 1024 * 1024;

class DioHttpClient extends http.BaseClient {
  DioHttpClient({
    this._proxy,
    CancelToken? cancelToken,
    Duration? timeout,
    this.logRequests = true,
    HttpClientAdapter? adapter,
  }) : _cancelToken = cancelToken ?? CancelToken(),
       _options = BaseOptions(
         connectTimeout: timeout,
         sendTimeout: timeout,
         receiveTimeout: timeout,
         validateStatus: (_) => true,
       ) {
    _adapter =
        adapter ??
        IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.connectionTimeout = null;
            client.idleTimeout = const Duration(days: 3650);
            if (_proxy?.isValid == true) {
              final p = _proxy!;
              if (p.type == 'socks5') {
                Future<InternetAddress?>? proxyAddrFuture;
                client.connectionFactory = (uri, proxyHost, proxyPort) async {
                  proxyAddrFuture ??= _resolveProxyAddress(p.host);
                  final proxyAddr = await proxyAddrFuture;
                  if (proxyAddr == null) {
                    return _directConnection(uri, null);
                  }

                  final proxies = <socks.ProxySettings>[
                    socks.ProxySettings(
                      proxyAddr,
                      p.port,
                      username: p.username,
                      password: p.password,
                    ),
                  ];

                  final socket = socks.SocksTCPClient.connect(
                    proxies,
                    InternetAddress(uri.host, type: InternetAddressType.unix),
                    uri.port,
                  );

                  if (uri.scheme == 'https') {
                    final Future<SecureSocket> secureSocket;
                    return ConnectionTask.fromSocket(
                      secureSocket = (await socket).secure(uri.host),
                      () async => (await secureSocket).close(),
                    );
                  }

                  return ConnectionTask.fromSocket(
                    socket,
                    () async => (await socket).close(),
                  );
                };
              } else {
                client.findProxy = (_) => 'PROXY ${p.host}:${p.port}';
                if (p.username != null && p.username!.trim().isNotEmpty) {
                  client.addProxyCredentials(
                    p.host,
                    p.port,
                    '',
                    HttpClientBasicCredentials(p.username!, p.password ?? ''),
                  );
                }
              }
            }
            return client;
          },
        );
  }

  final bool logRequests;
  final BaseOptions _options;
  late final HttpClientAdapter _adapter;
  final NetworkProxyConfig? _proxy;
  final CancelToken _cancelToken;

  @override
  void close() {
    // Closing a per-round client must not cancel the conversation's shared
    // token: a tool continuation can still use it for its next request.
    _adapter.close();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final reqId = RequestLogger.nextRequestId();
    final uri = request.url;
    final method = request.method.toUpperCase();

    // A body that cannot be read (a file upload whose file went away) must
    // fail as such, not go out empty and come back as the server's 400.
    final bodyBytes = await request.finalize().toBytes();

    final reqHeaders = Map<String, String>.from(request.headers);
    if (!reqHeaders.keys.any((key) => key.toLowerCase() == 'user-agent')) {
      reqHeaders['User-Agent'] = 'Kelivo';
    }

    if (logRequests && RequestLogger.enabled) {
      RequestLogger.logLine(
        '[REQ $reqId] $method ${LogRedactor.redactUrl(uri.toString())}',
      );
      if (reqHeaders.isNotEmpty) {
        RequestLogger.logLine(
          '[REQ $reqId] headers=${RequestLogger.encodeObject(LogRedactor.redactHeaders(reqHeaders))}',
        );
      }
      if (bodyBytes.length > _loggedBodyLimit) {
        // A file upload is bytes the log has no use for, and decoding them
        // would hold the body in memory a second and third time.
        RequestLogger.logLine(
          '[REQ $reqId] body=<${bodyBytes.length} bytes, not logged>',
        );
      } else if (bodyBytes.isNotEmpty) {
        final decoded = RequestLogger.safeDecodeUtf8(bodyBytes);
        // Elide first: a multi-MB image request drops to a few KB, which
        // brings it back under redactBody's JSON-parsing size limit.
        final bodyText = decoded.isNotEmpty
            ? LogRedactor.redactBody(RequestLogger.elidePayloads(decoded))
            : 'base64:${base64Encode(bodyBytes)}';
        RequestLogger.logLine(
          '[REQ $reqId] body=${RequestLogger.escape(bodyText)}',
        );
      }
    }

    try {
      if (_cancelToken.isCancelled) throw _cancelToken.cancelError!;
      if (bodyBytes.isNotEmpty) {
        reqHeaders[Headers.contentLengthHeader] = bodyBytes.length.toString();
      }
      final options = Options(
        method: method,
        headers: reqHeaders,
        responseType: ResponseType.stream,
        followRedirects: request.followRedirects,
        maxRedirects: request.maxRedirects,
        receiveDataWhenStatusError: true,
      ).compose(_options, uri.toString(), cancelToken: _cancelToken);
      _cancelToken.requestOptions = options;
      // Dio's high-level response handler eagerly drains the socket into an
      // unbounded controller. Its public adapter preserves the transport and
      // proxy/timeout implementation while letting our consumer own demand.
      final resp = await _awaitResponseOrCancel(
        _adapter.fetch(
          options,
          bodyBytes.isEmpty ? null : Stream<Uint8List>.value(bodyBytes),
          _cancelToken.whenCancel,
        ),
        _cancelToken,
      );
      final statusCode = resp.statusCode;
      final headers = <String, String>{};
      resp.headers.forEach((name, values) {
        if (values.isEmpty) return;
        headers[name] = values.join(',');
      });

      if (logRequests && RequestLogger.enabled) {
        RequestLogger.logLine('[RES $reqId] status=$statusCode');
        if (headers.isNotEmpty) {
          RequestLogger.logLine(
            '[RES $reqId] headers=${RequestLogger.encodeObject(LogRedactor.redactHeaders(headers))}',
          );
        }
      }

      final body = resp;
      final int? contentLength = (body.contentLength >= 0)
          ? body.contentLength
          : null;
      const maxErrorBodyBytes = 256 * 1024;

      final logChunks =
          (logRequests && RequestLogger.enabled) && RequestLogger.saveOutput;
      final controller = StreamController<List<int>>(sync: true);
      final responseState = _ResponseStreamState(body.stream, controller);
      controller.onListen = () {
        if (responseState.finished) return;
        Stream<Uint8List> source = body.stream;
        final timeout = options.receiveTimeout;
        if (timeout != null && timeout > Duration.zero) {
          // Stream.timeout suspends its timer while the consumer is paused.
          source = source.timeout(
            timeout,
            onTimeout: (sink) {
              sink.addError(
                DioException.receiveTimeout(
                  timeout: timeout,
                  requestOptions: options,
                ),
              );
              sink.close();
            },
          );
        }
        responseState.subscription = source.listen(
          (chunk) {
            controller.add(chunk);
            if (logChunks) {
              final s = RequestLogger.safeDecodeUtf8(chunk);
              if (s.isNotEmpty) {
                RequestLogger.logLine(
                  '[RES $reqId] chunk=${RequestLogger.escape(LogRedactor.redactBody(RequestLogger.elidePayloads(s)))}',
                );
              }
            }
          },
          onError: (Object error, StackTrace stack) {
            responseState.finished = true;
            if (logRequests && RequestLogger.enabled) {
              RequestLogger.logLine(
                '[RES $reqId] error=${RequestLogger.escape(LogRedactor.redactText(error.toString()))}',
              );
            }
            controller.addError(error, stack);
            unawaited(controller.close());
          },
          onDone: () {
            responseState.finished = true;
            if (logRequests && RequestLogger.enabled) {
              RequestLogger.logLine('[RES $reqId] done');
            }
            unawaited(controller.close());
          },
          cancelOnError: true,
        );
      };
      controller.onPause = () => responseState.subscription?.pause();
      controller.onResume = () => responseState.subscription?.resume();
      controller.onCancel = () async {
        responseState.finished = true;
        final subscription = responseState.subscription;
        responseState.subscription = null;
        await subscription?.cancel();
      };
      _cancelResponseWithToken(_cancelToken, responseState);

      // Error payloads are small; read them now so the log does not depend
      // on the caller consuming the stream (and the viewer can parse body=).
      if ((logRequests && RequestLogger.enabled) && statusCode >= 400) {
        final bytes = await _readLimited(controller.stream, maxErrorBodyBytes);
        final text = RequestLogger.safeDecodeUtf8(bytes);
        if (text.isNotEmpty) {
          RequestLogger.logLine(
            '[RES $reqId] body=${RequestLogger.escape(LogRedactor.redactBody(RequestLogger.elidePayloads(text)))}',
          );
        }
        RequestLogger.logLine('[RES $reqId] done');
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([if (bytes.isNotEmpty) bytes]),
          statusCode,
          contentLength: contentLength ?? (bytes.isEmpty ? 0 : bytes.length),
          request: request,
          headers: headers,
          isRedirect: resp.isRedirect,
          reasonPhrase: resp.statusMessage,
        );
      }

      return http.StreamedResponse(
        http.ByteStream(controller.stream),
        statusCode,
        contentLength: contentLength,
        request: request,
        headers: headers,
        isRedirect: resp.isRedirect,
        reasonPhrase: resp.statusMessage,
      );
    } on DioException catch (e) {
      if (logRequests && RequestLogger.enabled) {
        RequestLogger.logLine(
          '[RES $reqId] dio_error=${RequestLogger.escape(LogRedactor.redactText(RequestLogger.elidePayloads(e.toString())))}',
        );
        final status = e.response?.statusCode;
        if (status != null) {
          RequestLogger.logLine('[RES $reqId] status=$status');
        }
        final data = e.response?.data;
        if (data != null && data is! ResponseBody) {
          RequestLogger.logLine(
            '[RES $reqId] body=${RequestLogger.escape(LogRedactor.redactBody(RequestLogger.elidePayloads(data.toString())))}',
          );
        }
      }
      throw http.ClientException(e.toString(), uri);
    } catch (e) {
      if (logRequests && RequestLogger.enabled) {
        RequestLogger.logLine(
          '[RES $reqId] error=${RequestLogger.escape(LogRedactor.redactText(e.toString()))}',
        );
      }
      throw http.ClientException(e.toString(), uri);
    }
  }
}

Future<ResponseBody> _awaitResponseOrCancel(
  Future<ResponseBody> response,
  CancelToken token,
) {
  final result = Completer<ResponseBody>();
  // Clear the pending completer after either outcome so a shared conversation
  // token cannot retain responses from completed tool rounds.
  Completer<ResponseBody>? pending = result;
  unawaited(
    token.whenCancel.then((error) {
      final completion = pending;
      pending = null;
      completion?.completeError(error, error.stackTrace);
    }),
  );
  response
      .then<void>(
        (body) async {
          final completion = pending;
          pending = null;
          if (completion == null) {
            // IO adapters may still be waiting for DNS/TLS when cancellation
            // wins. Release any body that arrives after the caller has left.
            await body.stream.listen((_) {}, onError: (Object _) {}).cancel();
          } else {
            completion.complete(body);
          }
        },
        onError: (Object error, StackTrace stack) {
          final completion = pending;
          pending = null;
          completion?.completeError(error, stack);
        },
      )
      // A late transport/cleanup error must not report cancellation twice.
      .ignore();
  return result.future;
}

// The shared conversation token can outlive many tool rounds. Retain each
// response only weakly so completed streams and their buffers can be collected.
void _cancelResponseWithToken(CancelToken token, _ResponseStreamState state) {
  final weakState = WeakReference(state);
  token.whenCancel.then((error) => weakState.target?.cancel(error));
}

class _ResponseStreamState {
  _ResponseStreamState(this.source, this.controller);

  final Stream<Uint8List> source;
  final StreamController<List<int>> controller;
  StreamSubscription<Uint8List>? subscription;
  bool finished = false;

  Future<void> cancel(Object error) async {
    if (finished || controller.isClosed) return;
    finished = true;
    controller.addError(error);
    unawaited(controller.close());
    // A caller can cancel between receiving headers and listening to the body.
    // Cancel that unopened body too, rather than leaving its socket alive.
    final active =
        subscription ?? source.listen((_) {}, onError: (Object _) {});
    subscription = null;
    await active.cancel();
  }
}
