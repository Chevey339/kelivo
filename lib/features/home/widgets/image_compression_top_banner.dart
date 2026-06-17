import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/image_compression_progress.dart';
import '../../../icons/lucide_adapter.dart';

/// 顶部图片压缩提示：压缩进行中显示整体进度条（done/total），
/// 一批完成后短暂显示一次「原图 → 压缩后」体积。无文案，靠图标+数字，
/// 避免引入本地化字符串。
class ImageCompressionTopBanner extends StatefulWidget {
  const ImageCompressionTopBanner({super.key});

  @override
  State<ImageCompressionTopBanner> createState() =>
      _ImageCompressionTopBannerState();
}

class _ImageCompressionTopBannerState extends State<ImageCompressionTopBanner> {
  final ImageCompressionProgress _p = ImageCompressionProgress.instance;
  int _lastToken = 0;
  bool _showResult = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _lastToken = _p.resultToken;
    _p.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    if (_p.resultToken != _lastToken) {
      _lastToken = _p.resultToken;
      _showResult = true;
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showResult = false);
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _p.removeListener(_onChange);
    super.dispose();
  }

  static String _fmt(int b) {
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)}MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)}KB';
    return '${b}B';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget? content;

    if (_p.active) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Lucide.ImageDown, size: 14, color: cs.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _p.value > 0 ? _p.value : null,
                minHeight: 5,
                backgroundColor: cs.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_p.done}/${_p.total}',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else if (_showResult && _p.lastCount > 0) {
      final saved = _p.lastSavedFrom - _p.lastSavedTo;
      final pct = _p.lastSavedFrom > 0
          ? (saved * 100 / _p.lastSavedFrom).round()
          : 0;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Lucide.ImageDown, size: 14, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            '${_fmt(_p.lastSavedFrom)} → ${_fmt(_p.lastSavedTo)}',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (pct > 0) ...[
            const SizedBox(width: 6),
            Text(
              '-$pct%',
              style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: content == null
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(20),
                  color: cs.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
    );
  }
}
