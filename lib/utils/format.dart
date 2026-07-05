String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  double s = bytes.toDouble();
  int u = 0;
  while (s >= 1024 && u < units.length - 1) {
    s /= 1024;
    u++;
  }
  final decimals = s < 10 && u > 0
      ? 2
      : s < 100 && u > 0
      ? 1
      : 0;
  return '${s.toStringAsFixed(decimals)} ${units[u]}';
}
