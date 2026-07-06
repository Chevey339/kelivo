import 'dart:io';

/// 检测 PNG 文件是否包含 alpha（透明）通道。
///
/// 读取 PNG IHDR chunk 的第 9 字节（colorType），不解码完整图像：
///   0 = Grayscale        (无 alpha)
///   2 = RGB              (无 alpha)
///   3 = Indexed          (无 alpha)
///   4 = Grayscale+Alpha  (有 alpha)
///   6 = RGBA             (有 alpha)
/// 仅当 colorType == 4 或 6 时返回 true。
///
/// 对非 PNG 文件、不存在或读取失败返回 false。
bool pngHasAlphaChannel(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return false;
    final ext = path.toLowerCase();
    if (!ext.endsWith('.png')) return false;

    // PNG signature (8 bytes) + IHDR chunk header (4 len + 4 type) + width(4) +
    // height(4) + bitDepth(1) + colorType(1) = 22 bytes offset to colorType.
    final raf = file.openSync(mode: FileMode.read);
    try {
      // Seek to colorType byte: 8(sig) + 4(len) + 4("IHDR") + 4(width) +
      // 4(height) + 1(bitDepth) = 25.
      raf.setPositionSync(25);
      final colorType = raf.readByteSync();
      return colorType == 4 || colorType == 6;
    } finally {
      raf.closeSync();
    }
  } catch (_) {
    return false;
  }
}
