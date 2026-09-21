import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

String oauthRandomString(int bytes) {
  final random = Random.secure();
  return base64UrlEncode(
    List<int>.generate(bytes, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
}

String oauthPkceChallenge(String verifier) => base64UrlEncode(
  sha256.convert(ascii.encode(verifier)).bytes,
).replaceAll('=', '');
