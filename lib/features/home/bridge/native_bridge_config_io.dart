import 'dart:io';

final class NativeBridgeConfig {
  const NativeBridgeConfig({
    required this.secret,
    required this.port,
    required this.maxBodyBytes,
  });

  static const defaultPort = 37964;
  static const defaultMaxBodyBytes = 1 << 20;

  final String secret;
  final int port;
  final int maxBodyBytes;

  static NativeBridgeConfig? fromEnvironment() {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return null;
    }
    final secret = Platform.environment['KELIVO_NATIVE_BRIDGE_SECRET'];
    if (secret == null || secret.isEmpty) return null;
    final parsedPort = int.tryParse(
      Platform.environment['KELIVO_NATIVE_BRIDGE_PORT'] ?? '',
    );
    final port = parsedPort != null && parsedPort >= 0 && parsedPort <= 65535
        ? parsedPort
        : defaultPort;
    final parsedMaxBody = int.tryParse(
      Platform.environment['KELIVO_NATIVE_BRIDGE_MAX_BODY_BYTES'] ?? '',
    );
    final maxBodyBytes =
        parsedMaxBody != null && parsedMaxBody > 0 && parsedMaxBody <= 16 << 20
        ? parsedMaxBody
        : defaultMaxBodyBytes;
    return NativeBridgeConfig(
      secret: secret,
      port: port,
      maxBodyBytes: maxBodyBytes,
    );
  }
}
