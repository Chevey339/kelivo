import 'dart:io';

/// Recognizes public IP addresses, including IPs carried in IPv6 prefixes.
bool isPublicInternetAddress(
  InternetAddress address, {
  bool allowProxyFakeIp = false,
}) {
  final bytes = address.rawAddress;
  if (bytes.length == 4) {
    // Proxy/VPN fake-IP DNS commonly uses 198.18.0.0/15; TLS still validates
    // the original hostname. Literal addresses never enable this exception.
    return _isPublicIpv4(bytes) ||
        (allowProxyFakeIp && _isProxyFakeIpv4(bytes));
  }
  if (bytes.length != 16) return false;

  if (_allZero(bytes, 0, 10) && bytes[10] == 0xff && bytes[11] == 0xff) {
    return _isPublicIpv4(bytes.sublist(12));
  }
  if (_allZero(bytes, 0, 12)) {
    return _isPublicIpv4(bytes.sublist(12));
  }
  if (_matches(bytes, const [0x00, 0x64, 0xff, 0x9b], 0) &&
      _allZero(bytes, 4, 12)) {
    return _isPublicIpv4(bytes.sublist(12));
  }

  if ((bytes[0] & 0xfe) == 0xfc ||
      bytes[0] == 0xff ||
      (bytes[0] == 0xfe && (bytes[1] & 0xc0) != 0x00) ||
      (_allZero(bytes, 0, 15) && bytes[15] <= 1) ||
      (_matches(bytes, const [0x00, 0x64, 0xff, 0x9b, 0x00, 0x01], 0)) ||
      (_matches(bytes, const [0x01, 0x00], 0) && _allZero(bytes, 2, 8)) ||
      _matches(bytes, const [0x20, 0x01, 0x00, 0x00], 0) ||
      _matches(bytes, const [0x20, 0x01, 0x00, 0x02], 0) ||
      _matches(bytes, const [0x20, 0x01, 0x0d, 0xb8], 0) ||
      (bytes[0] == 0x20 && bytes[1] == 0x01 && (bytes[2] & 0xf0) == 0x10) ||
      (bytes[0] == 0x20 && bytes[1] == 0x01 && (bytes[2] & 0xf0) == 0x20)) {
    return false;
  }
  if (bytes[0] == 0x20 && bytes[1] == 0x02) {
    return _isPublicIpv4(bytes.sublist(2, 6));
  }
  return (bytes[0] & 0xe0) == 0x20;
}

bool _isPublicIpv4(List<int> bytes) {
  if (bytes.length != 4) return false;
  final a = bytes[0];
  final b = bytes[1];
  final c = bytes[2];
  return !(a == 0 ||
      a == 10 ||
      a == 127 ||
      (a == 100 && b >= 64 && b <= 127) ||
      (a == 169 && b == 254) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 0 && c == 0) ||
      (a == 192 && b == 0 && c == 2) ||
      (a == 192 && b == 88 && c == 99) ||
      (a == 192 && b == 168) ||
      (a == 198 && (b == 18 || b == 19)) ||
      (a == 198 && b == 51 && c == 100) ||
      (a == 203 && b == 0 && c == 113) ||
      a >= 224);
}

bool _isProxyFakeIpv4(List<int> bytes) =>
    bytes.length == 4 && bytes[0] == 198 && (bytes[1] == 18 || bytes[1] == 19);

bool _allZero(List<int> bytes, int start, int end) {
  for (var index = start; index < end; index++) {
    if (bytes[index] != 0) return false;
  }
  return true;
}

bool _matches(List<int> bytes, List<int> prefix, int offset) {
  if (bytes.length < offset + prefix.length) return false;
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[offset + index] != prefix[index]) return false;
  }
  return true;
}
