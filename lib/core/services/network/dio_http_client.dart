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
  DioHttpClient({this._proxy, CancelToken? cancelToken, Duration? timeout})
    : _cancelToken = cancelToken ?? CancelToken(),
      _dio = Dio(
        BaseOptions(
          connectTimeout: timeout,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          validateStatus: (_) => true,
        ),
      ) {
    _dio.httpClientAdapter = IOHttpClientAdapter(
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

  final Dio _dio;
  final NetworkProxyConfig? _proxy;
  final CancelToken _cancelToken;

  @override
  void close() {
    // 注意：不要在这里取消 CancelToken！
    // close() 是在 finally 块中被调用的，此时流可能还没有被完全消费。
    // 如果取消 CancelToken，会中断 Dio 的请求，导致流收到错误，
    // 进而影响工具调用后的后续请求。
    // CancelToken 的取消应该只在 onCancel 回调中进行（用户主动取消订阅时）。
    // try {
    //   if (!_cancelToken.isCancelled) {
    //     _cancelToken.cancel('closed');
    //   }
    // } catch (_) {}
    // try {
    //   _dio.close(force: true);
    // } catch (_) {}
    try {
      _dio.close();
    } catch (_) {}
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
    reqHeaders.putIfAbsent('User-Agent', () => 'Kelivo');

    if (RequestLogger.enabled) {
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
      final resp = await _dio.request<ResponseBody>(
        uri.toString(),
        data: bodyBytes.isEmpty ? null : bodyBytes,
        options: Options(
          method: method,
          headers: reqHeaders,
          responseType: ResponseType.stream,
          followRedirects: request.followRedirects,
          maxRedirects: request.maxRedirects,
          receiveDataWhenStatusError: true,
        ),
        cancelToken: _cancelToken,
      );

      final statusCode = resp.statusCode ?? 0;
      final headers = <String, String>{};
      resp.headers.forEach((name, values) {
        if (values.isEmpty) return;
        headers[name] = values.join(',');
      });

      if (RequestLogger.enabled) {
        RequestLogger.logLine('[RES $reqId] status=$statusCode');
        if (headers.isNotEmpty) {
          RequestLogger.logLine(
            '[RES $reqId] headers=${RequestLogger.encodeObject(LogRedactor.redactHeaders(headers))}',
          );
        }
      }

      final body = resp.data!;
      final int? contentLength = (body.contentLength >= 0)
          ? body.contentLength
          : null;
      const maxErrorBodyBytes = 256 * 1024;

      // Error payloads are small; read them now so the log does not depend
      // on the caller consuming the stream (and the viewer can parse body=).
      if (RequestLogger.enabled && statusCode >= 400) {
        final bytes = await _readLimited(body.stream, maxErrorBodyBytes);
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

      final logChunks = RequestLogger.enabled && RequestLogger.saveOutput;
      final controller = StreamController<List<int>>(sync: true);
      controller.onListen = () {
        body.stream.listen(
          (chunk) {
            controller.add(chunk);
            if (logChunks) {
              final s = RequestLogger.safeDecodeUtf8(chunk);
              if (s.isNotEmpty) {
                // Elided per chunk: a payload split across chunk boundaries
                // is only partly caught, and capLine() bounds the rest.
                RequestLogger.logLine(
                  '[RES $reqId] chunk=${RequestLogger.escape(LogRedactor.redactBody(RequestLogger.elidePayloads(s)))}',
                );
              }
            }
          },
          onError: (e, st) {
            if (RequestLogger.enabled) {
              RequestLogger.logLine(
                '[RES $reqId] error=${RequestLogger.escape(LogRedactor.redactText(e.toString()))}',
              );
            }
            controller.addError(e, st);
            controller.close();
          },
          onDone: () {
            if (RequestLogger.enabled) {
              RequestLogger.logLine('[RES $reqId] done');
            }
            controller.close();
          },
          cancelOnError: false,
        );
      };
      controller.onCancel = () {
        // 注意：当 await for 循环被 break 中断时（如工具调用处理），Dart 会取消流订阅，
        // 触发 onCancel。这里不要做任何清理操作！
        //
        // 原因：
        // 1. 不能取消 _cancelToken - 会导致后续请求失败
        // 2. 不能调用 sub?.cancel() - 会影响 Dio 的 HTTP 连接状态，
        //    导致使用同一个 Dio 实例的后续请求失败
        // 3. 不能调用 controller.close() - controller 会在流自然结束时自动关闭
        //
        // 让旧的流自然结束或被垃圾回收，不要主动干预。
      };

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
      if (RequestLogger.enabled) {
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
      if (RequestLogger.enabled) {
        RequestLogger.logLine(
          '[RES $reqId] error=${RequestLogger.escape(LogRedactor.redactText(e.toString()))}',
        );
      }
      throw http.ClientException(e.toString(), uri);
    }
  }
}
