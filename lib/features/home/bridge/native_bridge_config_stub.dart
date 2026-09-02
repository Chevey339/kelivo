final class NativeBridgeConfig {
  const NativeBridgeConfig({
    required this.secret,
    required this.port,
    required this.maxBodyBytes,
  });

  final String secret;
  final int port;
  final int maxBodyBytes;

  static NativeBridgeConfig? fromEnvironment() => null;
}
