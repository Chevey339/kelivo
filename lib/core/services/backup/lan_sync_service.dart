import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data_sync.dart';

/// Errors raised by the LAN transfer layer. Backup validation and restore
/// errors continue to be raised by [DataSync].
class LanSyncException implements Exception {
  const LanSyncException(this.code, [this.details]);

  final String code;
  final String? details;

  @override
  String toString() => details == null
      ? 'LanSyncException($code)'
      : 'LanSyncException($code: $details)';
}

/// A short-lived HTTP share containing a single Kelivo backup archive.
///
/// The random token is part of the URL, requests are accepted only from local
/// addresses, and closing the session removes the temporary archive.
class LanSyncShareSession {
  LanSyncShareSession._({
    required this._server,
    required this._archive,
    required List<Uri> urls,
    required this.token,
    required this.pairingCode,
    required this.sessionId,
    required this.allowLoopbackRequests,
  }) : shareUrls = urls;

  static const String route = '/kelivo-sync/v1/backup';
  static const String pairRoute = '/kelivo-sync/v1/pair';
  static const int discoveryPort = 45836;
  static const String discoveryService = 'kelivo-lan-sync';

  final HttpServer _server;
  final File _archive;
  final List<Uri> shareUrls;
  final String token;
  final String pairingCode;
  final String sessionId;
  final bool allowLoopbackRequests;
  final StreamController<int> _transferController =
      StreamController<int>.broadcast();
  int _completedTransfers = 0;
  RawDatagramSocket? _broadcastSocket;
  Timer? _broadcastTimer;
  bool _broadcastAvailable = false;
  final List<DateTime> _allPairingFailures = [];
  final Map<String, List<DateTime>> _pairingFailures = {};
  bool _closed = false;

  Uri get primaryUrl => shareUrls.first;
  String get fileName => p.basename(_archive.path);
  int get completedTransfers => _completedTransfers;
  Stream<int> get transfers => _transferController.stream;
  bool get broadcastAvailable => _broadcastAvailable;

  static Future<LanSyncShareSession> start(
    File archive, {
    List<InternetAddress>? advertisedAddresses,
    InternetAddress? bindAddress,
    bool allowLoopback = false,
    int discoveryPortNumber = discoveryPort,
    List<InternetAddress>? broadcastTargets,
    bool enableBroadcast = true,
  }) async {
    if (!await archive.exists()) {
      throw const LanSyncException('archiveMissing');
    }

    final addresses = advertisedAddresses ?? await _localIpv4Addresses();
    if (addresses.isEmpty) {
      throw const LanSyncException('noLocalAddress');
    }

    final server = await HttpServer.bind(
      bindAddress ?? InternetAddress.anyIPv4,
      0,
      shared: false,
    );
    final token = _newToken();
    final pairingCode = _newPairingCode();
    final sessionId = _newSessionId();
    final urls = addresses
        .map(
          (address) => Uri(
            scheme: 'http',
            host: address.address,
            port: server.port,
            path: route,
            queryParameters: {'token': token},
          ),
        )
        .toList(growable: false);
    final session = LanSyncShareSession._(
      server: server,
      archive: archive,
      urls: urls,
      token: token,
      pairingCode: pairingCode,
      sessionId: sessionId,
      allowLoopbackRequests: allowLoopback,
    );
    server.listen(
      session._handleRequest,
      onError: (_) {},
      cancelOnError: false,
    );
    if (enableBroadcast) {
      await session._startBroadcasting(
        port: discoveryPortNumber,
        targets: broadcastTargets ?? _broadcastAddresses(addresses),
      );
    }
    return session;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');

    if (!_isPrivateAddress(
      request.connectionInfo?.remoteAddress,
      allowLoopback: allowLoopbackRequests,
    )) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    if (request.uri.path == pairRoute) {
      await _handlePairRequest(request);
      return;
    }

    if (request.uri.path != route ||
        !_tokensEqual(request.uri.queryParameters['token'], token)) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      response.headers.set('Allow', 'GET, HEAD');
      await response.close();
      return;
    }

    try {
      final size = await _archive.length();
      response.statusCode = HttpStatus.ok;
      response.headers.contentType = ContentType('application', 'zip');
      response.headers.contentLength = size;
      response.headers.set(
        'Content-Disposition',
        'attachment; filename="${p.basename(_archive.path)}"',
      );
      response.headers.set('X-Kelivo-Sync-Version', '1');
      if (request.method == 'HEAD') {
        await response.close();
        return;
      }
      await response.addStream(_archive.openRead());
      await response.close();
      _completedTransfers++;
      if (!_transferController.isClosed) {
        _transferController.add(_completedTransfers);
      }
    } catch (_) {
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _startBroadcasting({
    required int port,
    required List<InternetAddress> targets,
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      _broadcastSocket = socket;
      bool broadcast() {
        if (_closed) return false;
        final payload = utf8.encode(
          jsonEncode({
            'service': discoveryService,
            'version': 1,
            'session': sessionId,
            'port': _server.port,
          }),
        );
        var sent = false;
        for (final target in targets) {
          try {
            sent = (socket?.send(payload, target, port) ?? 0) > 0 || sent;
          } catch (_) {}
        }
        return sent;
      }

      _broadcastAvailable = broadcast();
      _broadcastTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _broadcastAvailable = broadcast(),
      );
    } catch (_) {
      socket?.close();
      _broadcastSocket = null;
      _broadcastAvailable = false;
    }
  }

  Future<void> _handlePairRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.set('X-Kelivo-Sync-Version', '1');
    if (request.method != 'POST') {
      response.statusCode = HttpStatus.methodNotAllowed;
      response.headers.set('Allow', 'POST');
      await response.close();
      return;
    }

    final remote = request.connectionInfo!.remoteAddress.address;
    if (_isPairingRateLimited(remote)) {
      response.statusCode = HttpStatus.tooManyRequests;
      await response.close();
      return;
    }

    Map<String, Object?> body;
    try {
      body = await _readSmallJsonObject(request);
    } catch (_) {
      response.statusCode = HttpStatus.badRequest;
      await response.close();
      return;
    }
    final suppliedCode = body['code'] as String?;
    final suppliedSession = body['session'] as String?;
    if (!_tokensEqual(suppliedSession, sessionId) ||
        !_tokensEqual(suppliedCode, pairingCode)) {
      _recordPairingFailure(remote);
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }

    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'token': token}));
    await response.close();
  }

  bool _isPairingRateLimited(String remote) {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    final failures = _pairingFailures[remote];
    failures?.removeWhere((time) => time.isBefore(cutoff));
    _allPairingFailures.removeWhere((time) => time.isBefore(cutoff));
    return (failures?.length ?? 0) >= 5 || _allPairingFailures.length >= 50;
  }

  void _recordPairingFailure(String remote) {
    final now = DateTime.now();
    _allPairingFailures.add(now);
    _pairingFailures.putIfAbsent(remote, () => []).add(now);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
    await _server.close(force: true);
    await _transferController.close();
    await DataSync.cleanupTemporaryBackupFile(_archive);
  }
}

class LanSyncClient {
  static const int maxArchiveBytes = 16 * 1024 * 1024 * 1024;

  /// Downloads a shared archive to an isolated temporary directory.
  ///
  /// Only literal private/link-local IPv4 URLs are accepted. This keeps a
  /// pasted or scanned link from turning the app into an arbitrary HTTP
  /// client. Loopback is available only for tests.
  static Future<File> download(
    String link, {
    void Function(int received, int? total)? onProgress,
    Directory? destinationDirectory,
    bool allowLoopback = false,
  }) async {
    final uri = _parseAndValidateUri(link, allowLoopback: allowLoopback);
    final tempRoot = destinationDirectory ?? await getTemporaryDirectory();
    final downloadDir = Directory(
      p.join(
        tempRoot.path,
        'kelivo_lan_sync_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await downloadDir.create(recursive: true);
    final output = File(p.join(downloadDir.path, 'lan_sync_backup.zip'));
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 30)
      ..autoUncompress = false;

    IOSink? sink;
    var completed = false;
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      // Never follow a response to a host that did not pass the private-address
      // validation above.
      request.followRedirects = false;
      request.headers.set('Accept', 'application/zip');
      request.headers.set('Cache-Control', 'no-store');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok ||
          response.headers.value('X-Kelivo-Sync-Version') != '1') {
        throw LanSyncException('connectionRejected', '${response.statusCode}');
      }
      final total = response.contentLength >= 0 ? response.contentLength : null;
      if (total != null && total > maxArchiveBytes) {
        throw const LanSyncException('archiveTooLarge');
      }

      sink = output.openWrite();
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 45))) {
        received += chunk.length;
        if (received > maxArchiveBytes || (total != null && received > total)) {
          throw const LanSyncException('archiveTooLarge');
        }
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (total != null && received != total) {
        throw LanSyncException('incompleteDownload', '$received/$total');
      }
      if (received == 0) {
        throw const LanSyncException('emptyArchive');
      }
      completed = true;
      return output;
    } on LanSyncException {
      rethrow;
    } on TimeoutException catch (error) {
      throw LanSyncException('timeout', error.toString());
    } on SocketException catch (error) {
      throw LanSyncException('connectionFailed', error.message);
    } finally {
      client.close(force: true);
      if (sink != null) {
        await sink.close();
      }
      if (!completed) {
        try {
          if (await downloadDir.exists()) {
            await downloadDir.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }

  static Uri _parseAndValidateUri(String link, {required bool allowLoopback}) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.path != LanSyncShareSession.route ||
        !uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.queryParameters['token']?.isNotEmpty != true) {
      throw const LanSyncException('invalidLink');
    }
    final address = InternetAddress.tryParse(uri.host);
    if (address == null ||
        !_isPrivateAddress(address, allowLoopback: allowLoopback)) {
      throw const LanSyncException('nonLocalAddress');
    }
    return uri;
  }
}

/// Finds a temporarily advertised Kelivo share and exchanges a six-digit code
/// for the high-entropy download token. Discovery packets never contain either
/// the code or the token.
class LanSyncDiscovery {
  static Future<String> findByPairingCode(
    String code, {
    Duration timeout = const Duration(seconds: 8),
    int port = LanSyncShareSession.discoveryPort,
    InternetAddress? bindAddress,
    bool allowLoopback = false,
  }) async {
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw const LanSyncException('invalidPairingCode');
    }

    RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(
        bindAddress ?? InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
    } on SocketException catch (error) {
      throw LanSyncException('discoveryUnavailable', error.message);
    }

    final completer = Completer<String>();
    final attempted = <String>{};
    final inFlight = <String>{};
    late final StreamSubscription<RawSocketEvent> subscription;
    late final Timer timer;

    Future<void> inspect(Datagram datagram) async {
      final address = datagram.address;
      if (!_isPrivateAddress(address, allowLoopback: allowLoopback) ||
          datagram.data.length > 1024) {
        return;
      }

      Map<String, Object?> announcement;
      try {
        final decoded = jsonDecode(utf8.decode(datagram.data));
        if (decoded is! Map) return;
        announcement = Map<String, Object?>.from(decoded);
      } catch (_) {
        return;
      }
      if (announcement['service'] != LanSyncShareSession.discoveryService ||
          announcement['version'] != 1) {
        return;
      }
      final session = announcement['session'];
      final httpPort = announcement['port'];
      if (session is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(session) ||
          httpPort is! int ||
          httpPort < 1 ||
          httpPort > 65535) {
        return;
      }

      final key = '${address.address}:$httpPort:$session';
      if (attempted.contains(key) || !inFlight.add(key)) return;
      try {
        final link = await _pairWithDevice(
          address: address,
          port: httpPort,
          session: session,
          code: normalizedCode,
        );
        if (link != null && !completer.isCompleted) {
          completer.complete(link);
        } else {
          attempted.add(key);
        }
      } on LanSyncException catch (error) {
        if (error.code == 'pairingRateLimited' && !completer.isCompleted) {
          completer.completeError(error);
        } else {
          attempted.add(key);
        }
      } finally {
        inFlight.remove(key);
      }
    }

    subscription = socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        Datagram? datagram;
        while ((datagram = socket.receive()) != null) {
          unawaited(inspect(datagram!));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(
            LanSyncException('discoveryUnavailable', error.toString()),
            stackTrace,
          );
        }
      },
      cancelOnError: false,
    );
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(const LanSyncException('pairingNotFound'));
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
      socket.close();
    }
  }

  static Future<String?> _pairWithDevice({
    required InternetAddress address,
    required int port,
    required String session,
    required String code,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..idleTimeout = const Duration(seconds: 3);
    try {
      final uri = Uri(
        scheme: 'http',
        host: address.address,
        port: port,
        path: LanSyncShareSession.pairRoute,
      );
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 3));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'session': session, 'code': code}));
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode == HttpStatus.forbidden) {
        await response.drain<void>();
        return null;
      }
      if (response.statusCode == HttpStatus.tooManyRequests) {
        await response.drain<void>();
        throw const LanSyncException('pairingRateLimited');
      }
      if (response.statusCode != HttpStatus.ok ||
          response.headers.value('X-Kelivo-Sync-Version') != '1') {
        await response.drain<void>();
        return null;
      }
      final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) {
        if (buffer.length + chunk.length > 1024) {
          throw const LanSyncException('invalidPairingResponse');
        }
        return buffer..addAll(chunk);
      });
      final decoded = jsonDecode(utf8.decode(bytes));
      final token = decoded is Map ? decoded['token'] : null;
      if (token is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{24,128}$').hasMatch(token)) {
        throw const LanSyncException('invalidPairingResponse');
      }
      return Uri(
        scheme: 'http',
        host: address.address,
        port: port,
        path: LanSyncShareSession.route,
        queryParameters: {'token': token},
      ).toString();
    } on LanSyncException {
      rethrow;
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

Future<List<InternetAddress>> _localIpv4Addresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
    includeLinkLocal: true,
  );
  final addresses = <InternetAddress>[];
  final seen = <String>{};
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (_isPrivateAddress(address) && seen.add(address.address)) {
        addresses.add(address);
      }
    }
  }
  addresses.sort((a, b) => _addressPriority(a).compareTo(_addressPriority(b)));
  return addresses;
}

List<InternetAddress> _broadcastAddresses(List<InternetAddress> addresses) {
  final result = <InternetAddress>[InternetAddress('255.255.255.255')];
  final seen = <String>{'255.255.255.255'};
  for (final address in addresses) {
    final bytes = address.rawAddress;
    if (bytes.length != 4 || address.isLoopback) continue;
    // Dart doesn't expose interface netmasks. A /24 directed broadcast covers
    // the overwhelmingly common home/office layout, while the limited
    // broadcast above covers other subnet sizes when the OS permits it.
    final directed = '${bytes[0]}.${bytes[1]}.${bytes[2]}.255';
    if (seen.add(directed)) result.add(InternetAddress(directed));
  }
  return result;
}

Future<Map<String, Object?>> _readSmallJsonObject(HttpRequest request) async {
  final bytes = <int>[];
  await for (final chunk in request) {
    if (bytes.length + chunk.length > 1024) {
      throw const FormatException('request_too_large');
    }
    bytes.addAll(chunk);
  }
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) throw const FormatException('object_required');
  return Map<String, Object?>.from(decoded);
}

int _addressPriority(InternetAddress address) {
  final bytes = address.rawAddress;
  if (bytes.length != 4) return 99;
  if (bytes[0] == 192 && bytes[1] == 168) return 0;
  if (bytes[0] == 10) return 1;
  if (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) return 2;
  if (bytes[0] == 169 && bytes[1] == 254) return 3;
  return 99;
}

bool _isPrivateAddress(InternetAddress? address, {bool allowLoopback = false}) {
  if (address == null || address.type != InternetAddressType.IPv4) return false;
  if (address.isLoopback) return allowLoopback;
  final bytes = address.rawAddress;
  if (bytes.length != 4) return false;
  return bytes[0] == 10 ||
      (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
      (bytes[0] == 192 && bytes[1] == 168) ||
      (bytes[0] == 169 && bytes[1] == 254);
}

String _newToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String _newPairingCode() =>
    Random.secure().nextInt(1000000).toString().padLeft(6, '0');

String _newSessionId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

bool _tokensEqual(String? left, String right) {
  if (left == null || left.length != right.length) return false;
  var difference = 0;
  for (var i = 0; i < right.length; i++) {
    difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
  }
  return difference == 0;
}
