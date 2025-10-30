import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';

// =============================================================================
// 动画时长配置 - Windows 桌面端优化版本
// =============================================================================
// 
// 版本历史：
// v1.0 (原始): Fast=180ms, Normal=240ms, Slow=320ms
// v1.1 (优化): Fast=150ms, Normal=200ms, Slow=280ms (当前)
//
// 回退方法：将下方数值改回原始值即可
// =============================================================================

// Windows 桌面端优化：更快、更流畅的动画响应
// 适合鼠标交互，比触摸屏需要更快的视觉反馈
const Duration kAnimFast = Duration(milliseconds: 150);  // 原始: 180ms
const Duration kAnim = Duration(milliseconds: 200);      // 原始: 240ms  
const Duration kAnimSlow = Duration(milliseconds: 280);  // 原始: 320ms

// =============================================================================
// 备份：原始动画时长（如需回退，取消注释并注释上方代码）
// =============================================================================
// const Duration kAnimFast = Duration(milliseconds: 180);
// const Duration kAnim = Duration(milliseconds: 240);
// const Duration kAnimSlow = Duration(milliseconds: 320);

// =============================================================================
// Windows 桌面端专用动画曲线
// =============================================================================
// 使用更适合桌面端的缓动曲线，提供更专业的交互体验
const Curve kDesktopCurve = Curves.easeOutCubic;        // 主要曲线
const Curve kDesktopCurveFast = Curves.easeOut;         // 快速动画
const Curve kDesktopCurveSmooth = Curves.easeInOutCubic; // 平滑过渡

// A compact AnimatedSwitcher for icon glyph/state changes.
class AnimatedIconSwap extends StatelessWidget {
  const AnimatedIconSwap({
    super.key,
    required this.child,
    this.duration = kAnim,
  });
  final Widget child;
  final Duration duration;
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, anim) => FadeScaleTransition(animation: anim, child: child),
      child: child,
    );
  }
}

// A simple text switcher: fade + slide up on change.
class AnimatedTextSwap extends StatelessWidget {
  const AnimatedTextSwap({
    super.key,
    required this.text,
    this.style,
    this.duration = kAnim,
    this.maxLines,
    this.overflow,
  });
  final String text;
  final TextStyle? style;
  final Duration duration;
  final int? maxLines;
  final TextOverflow? overflow;
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[...previousChildren, if (currentChild != null) currentChild],
        );
      },
      transitionBuilder: (child, anim) {
        // Windows 桌面端优化：减小滑动距离，更精细的动画
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.10),  // 原始: 0.15，现在更细腻
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: anim,
          curve: kDesktopCurve,
        ));
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(text, key: ValueKey(text), style: style, maxLines: maxLines, overflow: overflow),
    );
  }
}

// Handy appear animation using flutter_animate (fade + slight Y move)
extension Appear on Widget {
  Widget appear({
    Duration duration = kAnim,
    double dy = 0.02,
    double begin = 0,
    Curve curve = kDesktopCurve,  // 新增：可自定义曲线
  }) {
    return animate()
        .fadeIn(duration: duration, begin: begin, curve: curve)
        .moveY(begin: dy, end: 0, duration: duration, curve: curve);
  }
}

// =============================================================================
// 新增：Windows 桌面端专用动画组件
// =============================================================================

/// Windows 桌面端按钮按下效果 - 轻微缩放 + 颜色变化
class DesktopPressEffect extends StatefulWidget {
  const DesktopPressEffect({
    super.key,
    required this.child,
    this.onPressed,
    this.scaleDown = 0.98,  // 按下时缩放比例
    this.duration = kAnimFast,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double scaleDown;
  final Duration duration;

  @override
  State<DesktopPressEffect> createState() => _DesktopPressEffectState();
}

class _DesktopPressEffectState extends State<DesktopPressEffect> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed?.call();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: _isPressed ? widget.scaleDown : 1.0),
          duration: widget.duration,
          curve: kDesktopCurveFast,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Windows 桌面端悬停效果 - 平滑的颜色/透明度过渡
class DesktopHoverEffect extends StatefulWidget {
  const DesktopHoverEffect({
    super.key,
    required this.builder,
    this.duration = kAnimFast,
  });

  final Widget Function(bool isHovered) builder;
  final Duration duration;

  @override
  State<DesktopHoverEffect> createState() => _DesktopHoverEffectState();
}

class _DesktopHoverEffectState extends State<DesktopHoverEffect> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedSwitcher(
        duration: widget.duration,
        child: widget.builder(_isHovered),
      ),
    );
  }
}

/// Windows 桌面端列表项动画 - 延迟渐显效果
extension DesktopListAnimation on Widget {
  Widget staggeredAppear(int index, {
    Duration baseDelay = const Duration(milliseconds: 30),
    Duration animDuration = kAnim,
  }) {
    final delay = baseDelay * index;
    return animate()
        .fadeIn(
          duration: animDuration,
          delay: delay,
          curve: kDesktopCurve,
        )
        .moveY(
          begin: 0.02,
          end: 0,
          duration: animDuration,
          delay: delay,
          curve: kDesktopCurve,
        );
  }
}
