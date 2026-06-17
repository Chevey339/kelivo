import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../utils/image_compressor.dart';

/// 全局图片压缩进度/结果通知器（单例）。
///
/// 顶部横幅 [ImageCompressionTopBanner] 监听它：压缩进行中显示整体进度条
/// （done/total），一批压缩完成后通过 [resultToken] 触发一次「原图 → 压缩后」
/// 体积提示。各入图路径在压缩前调用 [start]，每张完成调用 [step]，整批结束
/// 调用 [finishBatch]（即使有图片被跳过/取消也能正确收尾）。
class ImageCompressionProgress extends ChangeNotifier {
  ImageCompressionProgress._();
  static final ImageCompressionProgress instance = ImageCompressionProgress._();

  int total = 0;
  int done = 0;
  int originalBytes = 0;
  int compressedBytes = 0;

  // 最近一批完成后的汇总，供顶部「一次性」体积提示使用。
  int lastSavedFrom = 0;
  int lastSavedTo = 0;
  int lastCount = 0;
  int resultToken = 0;

  // 未结束的批次数。支持并发摄入：仅当所有批次都结束后才出结果并重置，
  // 避免一个批次的 finishBatch 把仍在进行的另一批次状态清空。
  int _outstanding = 0;

  bool get active => total > 0;
  double get value => total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;

  /// 在压缩一批 [count] 张图片前调用。可在已有批次进行中追加。
  void start(int count) {
    if (count <= 0) return;
    if (_outstanding == 0) {
      done = 0;
      originalBytes = 0;
      compressedBytes = 0;
      total = 0;
    }
    _outstanding += 1;
    total += count;
    notifyListeners();
  }

  /// 每张图片压缩完成后调用。
  void step({required int original, required int compressed}) {
    done += 1;
    originalBytes += original;
    compressedBytes += compressed;
    notifyListeners();
  }

  /// 整批结束时调用（务必在 finally 中调用，保证收尾）。
  void finishBatch() {
    if (_outstanding == 0) return;
    _outstanding -= 1;
    if (_outstanding > 0) return;
    if (done > 0) {
      lastSavedFrom = originalBytes;
      lastSavedTo = compressedBytes;
      lastCount = done;
      resultToken += 1;
    }
    total = 0;
    done = 0;
    originalBytes = 0;
    compressedBytes = 0;
    notifyListeners();
  }

  /// 压缩单张并上报进度。压缩开关由调用方判断（仅在开启时调用本方法）。
  /// 不再限制尺寸（maxDimension: 0），仅按质量压缩。返回最终路径
  /// （扩展名可能变化，如 png → jpg）。
  Future<String> compressAndReport(String path, {required int quality}) async {
    int orig = 0;
    try {
      orig = await File(path).length();
    } catch (_) {}
    final out = await ImageCompressor.compressIfNeeded(
      path,
      enabled: true,
      maxDimension: 0,
      quality: quality,
    );
    int comp = orig;
    try {
      comp = await File(out).length();
    } catch (_) {}
    step(original: orig, compressed: comp);
    return out;
  }
}
