import 'dart:async';
import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../network/public_internet_address.dart';

const _networkTimeout = Duration(seconds: 5);

http.Client createMcpOAuthDiscoveryHttpClient() {
  if (Platform.isIOS) {
    return CupertinoClient.fromSessionConfiguration(
      URLSessionConfiguration.ephemeralSessionConfiguration(),
    );
  }
  final client = HttpClient();
  client.connectionTimeout = _networkTimeout;
  return IOClient(client);
}

Future<void> validateMcpOAuthPublicUri(Uri uri) async {
  await _publicAddresses(uri.host);
}

Future<List<InternetAddress>> _publicAddresses(String host) async {
  final parsed = InternetAddress.tryParse(host);
  final addresses = parsed == null
      ? await InternetAddress.lookup(host).timeout(_networkTimeout)
      : <InternetAddress>[parsed];
  if (addresses.isEmpty ||
      addresses.any(
        (address) =>
            !isPublicInternetAddress(address, allowProxyFakeIp: parsed == null),
      )) {
    throw SocketException(
      'OAuth discovery host does not resolve exclusively to public addresses',
      address: parsed,
    );
  }
  return addresses;
}
