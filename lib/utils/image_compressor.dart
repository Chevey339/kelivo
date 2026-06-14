import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// 图片压缩工具
///
/// 解码 -> 按强度可选缩放 -> 重编码，压缩后替换 Kelivo 存储中的源文件。
/// 智能处理：GIF 动图跳过，透明 PNG 仍存 PNG，其余转 JPEG。
class ImageCompressor {
  ImageCompressor._();

  static const Set<String> _skipExt = {'.gif'};

  /// 压缩 [path] 指向的图片，[strength] 取值 0..100（越大压得越狠）。
  /// 返回压缩后文件路径；若跳过/失败/反而更大则返回原路径。
  /// 当生成新文件且路径不同时，会删除原始源文件。
  static Future<String> compressInPlace(String path, int strength) async {
    try {
      final s = strength.clamp(0, 100);
      if (s <= 0) return path;
      final ext = p.extension(path).toLowerCase();
      if (_skipExt.contains(ext)) return path;
      final file = File(path);
      if (!await file.exists()) return path;
      final origBytes = await file.readAsBytes();
      final result = await compute(_compressBytes, <String, dynamic>{
        'bytes': origBytes,
        'strength': s,
      });
      if (result == null) return path;
      final newBytes = result['bytes'] as Uint8List;
      final suffix = result['suffix'] as String;
      // 压缩后不更小则保留原图
      if (newBytes.length >= origBytes.length) return path;
      final dir = p.dirname(path);
      final base = p.basenameWithoutExtension(path);
      final newPath = p.join(dir, '$base$suffix');
      await File(newPath).writeAsBytes(newBytes, flush: true);
      if (newPath != path) {
        try {
          await file.delete();
        } catch (_) {}
      }
      return newPath;
    } catch (_) {
      return path;
    }
  }
}

/// 在后台 isolate 中执行解码与重编码（CPU 密集，避免卡 UI）。
Map<String, dynamic>? _compressBytes(Map<String, dynamic> job) {
  try {
    final bytes = job['bytes'] as Uint8List;
    final strength = job['strength'] as int;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    img.Image image = decoded;
    final maxDim = (4096 - strength * 30).clamp(1080, 4096).round();
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > maxDim) {
      if (image.width >= image.height) {
        image = img.copyResize(
          image,
          width: maxDim,
          interpolation: img.Interpolation.average,
        );
      } else {
        image = img.copyResize(
          image,
          height: maxDim,
          interpolation: img.Interpolation.average,
        );
      }
    }
    if (image.hasAlpha) {
      final level = (strength / 100 * 9).round().clamp(0, 9);
      final out = img.encodePng(image, level: level);
      return <String, dynamic>{'bytes': out, 'suffix': '.png'};
    }
    final quality = (95 - strength * 0.6).round().clamp(35, 95);
    final out = img.encodeJpg(image, quality: quality);
    return <String, dynamic>{'bytes': out, 'suffix': '.jpg'};
  } catch (_) {
    return null;
  }
}
