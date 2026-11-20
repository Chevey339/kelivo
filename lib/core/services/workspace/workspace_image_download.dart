import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../providers/settings_provider.dart';
import '../api/tool_call_cancellation.dart';
import '../mcp/kelivo_fetch/kelivo_fetch_server.dart';
import '../network/pinned_tls_socket.dart';
import '../network/public_internet_address.dart';
import '../tool_image.dart';

const _downloadTimeout = Duration(seconds: 10);
const _connectAttemptTimeout = Duration(seconds: 2);
const _maxRedirects = 3;

Future<Uint8List> downloadWorkspaceImage(
  Uri uri, {
  required void Function() checkAccess,
}) async {
  checkAccess();
  final client = HttpClient()
    ..userAgent = KelivoFetcher.userAgent
    ..autoUncompress = false
    ..findProxy = (_) => 'DIRECT';
  var closed = false;

  void checkRequestAccess(Uri url) {
    checkAccess();
    if (closed) throw const SocketException('Image download stopped');
    if (SettingsProvider.routesThroughGlobalProxy(url) ||
        HttpClient.findProxyFromEnvironment(url) != 'DIRECT') {
      throw const ToolImageException(
        'Image download requires a direct connection under the current proxy settings',
      );
    }
  }

  client.connectionFactory = (url, _, _) =>
      _connectToPublicAddress(url, () => checkRequestAccess(url));
  final stopped = Completer<Uint8List>();
  final unregister = ToolCallCancellation.current?.onCancel(
    () => stopped.completeError(StateError('tool_call_cancelled')),
  );
  try {
    return await Future.any([
      _download(client, uri, checkRequestAccess),
      stopped.future,
    ]).timeout(_downloadTimeout);
  } on TimeoutException {
    throw const ToolImageException('Image download timed out');
  } on FormatException {
    throw const ToolImageException('Invalid image URL or redirect');
  } on IOException {
    checkAccess();
    throw const ToolImageException('Could not download the image');
  } finally {
    unregister?.call();
    closed = true;
    client.close(force: true);
  }
}

Future<ConnectionTask<Socket>> _connectToPublicAddress(
  Uri uri,
  void Function() checkAccess,
) async {
  final literal = InternetAddress.tryParse(uri.host);
  final addresses = literal == null
      ? await InternetAddress.lookup(uri.host)
      : [literal];
  checkAccess();
  final https = uri.isScheme('https');
  // VPN fake-IP DNS still requires HTTPS to authenticate the original host.
  final allowFakeIp = https && literal == null;
  final public = addresses
      .where(
        (address) =>
            isPublicInternetAddress(address, allowProxyFakeIp: allowFakeIp),
      )
      .toList();
  if (public.isEmpty) {
    throw const ToolImageException(
      'Image URL must resolve to a public address',
    );
  }

  ConnectionTask<Socket>? pending;
  var stopped = false;
  Future<Socket> connect() async {
    for (final address in public) {
      if (stopped) break;
      checkAccess();
      try {
        final task = https
            ? await startPinnedTlsSocket(address, uri.port, uri.host)
            : await Socket.startConnect(address, uri.port);
        pending = task;
        if (stopped) task.cancel();
        final socket = public.length == 1
            ? await task.socket
            : await task.socket.timeout(
                _connectAttemptTimeout,
                onTimeout: () {
                  task.cancel();
                  unawaited(
                    task.socket.then<void>(
                      (socket) => socket.destroy(),
                      onError: (Object _) {},
                    ),
                  );
                  throw const SocketException(
                    'Image server connection timed out',
                  );
                },
              );
        if (!stopped) return socket;
        socket.destroy();
      } on IOException {
        // Try the next validated address when one route fails.
      }
    }
    throw const SocketException('Could not connect to the image server');
  }

  return ConnectionTask.fromSocket(connect(), () {
    stopped = true;
    pending?.cancel();
  });
}

Future<Uint8List> _download(
  HttpClient client,
  Uri uri,
  void Function(Uri url) checkAccess,
) async {
  for (var redirects = 0; ; redirects++) {
    if (!(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty) {
      throw const ToolImageException('Use a public HTTP(S) image URL');
    }
    checkAccess(uri);
    final request = await client.getUrl(uri);
    checkAccess(uri);
    request
      ..followRedirects = false
      ..persistentConnection = false;
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close();
    if (response.isRedirect) {
      await response.listen(null).cancel();
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.trim().isEmpty) {
        throw const ToolImageException('Image redirect has no location');
      }
      if (redirects == _maxRedirects) {
        throw const ToolImageException('Image URL redirected too many times');
      }
      uri = uri.resolve(location);
      continue;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.listen(null).cancel();
      throw ToolImageException(
        'Image download returned HTTP ${response.statusCode}',
      );
    }

    const tooLarge = ToolImageException('Image exceeds the 20 MiB file limit');
    if (response.contentLength > ToolImage.maxFileBytes) throw tooLarge;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > ToolImage.maxFileBytes) throw tooLarge;
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }
}
