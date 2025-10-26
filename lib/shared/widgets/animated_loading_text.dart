import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'typing_indicator.dart';
import 'modern_loading_indicator.dart';

/// 加载文本动画风格
enum LoadingTextStyle {
  shimmer,     // 闪烁渐变效果（默认）
  pulse,       // 脉动效果
  typewriter,  // 打字机效果
  modern,      // 现代风格（使用ModernLoadingIndicator）
}

/// 更美观的加载文本动画组件
/// 结合了点动画和文字渐变效果
class AnimatedLoadingText extends StatelessWidget {
  static LoadingTextStyle defaultStyle = LoadingTextStyle.shimmer;
  
  const AnimatedLoadingText({
    super.key,
    required this.text,
    this.textStyle,
    this.dotColor,
    this.dotSize = 8,
    this.dotGap = 3,
    this.showDots = true,
    this.style,
  });

  final String text;
  final TextStyle? textStyle;
  final Color? dotColor;
  final double dotSize;
  final double dotGap;
  final bool showDots;
  final LoadingTextStyle? style;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? AnimatedLoadingText.defaultStyle;
    
    // 根据不同风格返回不同的组件
    switch (effectiveStyle) {
      case LoadingTextStyle.pulse:
        return PulsingLoadingText(
          text: text,
          textStyle: textStyle,
          dotColor: dotColor,
          dotSize: dotSize,
          dotGap: dotGap,
          showDots: showDots,
        );
      case LoadingTextStyle.typewriter:
        return TypewriterLoadingText(
          text: text,
          textStyle: textStyle,
          dotColor: dotColor,
          dotSize: dotSize,
          dotGap: dotGap,
          showDots: showDots,
        );
      case LoadingTextStyle.modern:
        return CompactModernLoader(
          text: text,
          style: LoadingStyle.wave,
          color: dotColor,
        );
      case LoadingTextStyle.shimmer:
      default:
        return ShimmerLoadingText(
          text: text,
          textStyle: textStyle,
          dotColor: dotColor,
          dotSize: dotSize,
          dotGap: dotGap,
          showDots: showDots,
        );
    }
  }
}

/// 闪烁渐变效果的加载文本
class ShimmerLoadingText extends StatefulWidget {
  const ShimmerLoadingText({
    super.key,
    required this.text,
    this.textStyle,
    this.dotColor,
    this.dotSize = 8,
    this.dotGap = 3,
    this.showDots = true,
  });

  final String text;
  final TextStyle? textStyle;
  final Color? dotColor;
  final double dotSize;
  final double dotGap;
  final bool showDots;

  @override
  State<ShimmerLoadingText> createState() => _ShimmerLoadingTextState();
}

class _ShimmerLoadingTextState extends State<ShimmerLoadingText> 
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOutSine,
    ));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseTextStyle = widget.textStyle ?? TextStyle(
      fontSize: 14,
      color: cs.onSurface.withOpacity(0.6),
      fontStyle: FontStyle.italic,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDots) ...[
          DotsTypingIndicator(
            color: widget.dotColor ?? cs.primary,
            dotSize: widget.dotSize,
            gap: widget.dotGap,
          ),
          const SizedBox(width: 8),
        ],
        // 文字带渐变动画效果
        AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    baseTextStyle.color!.withOpacity(0.3),
                    baseTextStyle.color!,
                    baseTextStyle.color!.withOpacity(0.3),
                  ],
                  stops: [
                    (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                    _shimmerAnimation.value.clamp(0.0, 1.0),
                    (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds);
              },
              child: Text(
                widget.text,
                style: baseTextStyle,
              ),
            );
          },
        ),
      ],
    )
    // 整体淡入效果
    .animate()
    .fadeIn(duration: 300.ms, curve: Curves.easeOut)
    .slideX(begin: -0.05, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

/// 脉动式加载文本
class PulsingLoadingText extends StatelessWidget {
  const PulsingLoadingText({
    super.key,
    required this.text,
    this.textStyle,
    this.dotColor,
    this.dotSize = 8,
    this.dotGap = 3,
    this.showDots = true,
  });

  final String text;
  final TextStyle? textStyle;
  final Color? dotColor;
  final double dotSize;
  final double dotGap;
  final bool showDots;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseTextStyle = textStyle ?? TextStyle(
      fontSize: 14,
      color: cs.onSurface.withOpacity(0.6),
      fontStyle: FontStyle.italic,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDots) ...[
          DotsTypingIndicator(
            color: dotColor ?? cs.primary,
            dotSize: dotSize,
            gap: dotGap,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: baseTextStyle,
        )
        .animate(onPlay: (controller) => controller.repeat())
        .scaleXY(
          begin: 1.0,
          end: 1.05,
          duration: 1200.ms,
          curve: Curves.easeInOut,
        )
        .fade(
          begin: 0.5,
          end: 1.0,
          duration: 1200.ms,
          curve: Curves.easeInOut,
        ),
      ],
    )
    .animate()
    .fadeIn(duration: 300.ms, curve: Curves.easeOut);
  }
}

/// 类型写入效果的加载文本
class TypewriterLoadingText extends StatefulWidget {
  const TypewriterLoadingText({
    super.key,
    required this.text,
    this.textStyle,
    this.dotColor,
    this.dotSize = 8,
    this.dotGap = 3,
    this.showDots = true,
    this.typingSpeed = const Duration(milliseconds: 100),
  });

  final String text;
  final TextStyle? textStyle;
  final Color? dotColor;
  final double dotSize;
  final double dotGap;
  final bool showDots;
  final Duration typingSpeed;

  @override
  State<TypewriterLoadingText> createState() => _TypewriterLoadingTextState();
}

class _TypewriterLoadingTextState extends State<TypewriterLoadingText> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _textAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.typingSpeed * widget.text.length,
    );
    
    _textAnimation = IntTween(
      begin: 0,
      end: widget.text.length,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _controller.reset();
            _controller.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseTextStyle = widget.textStyle ?? TextStyle(
      fontSize: 14,
      color: cs.onSurface.withOpacity(0.6),
      fontStyle: FontStyle.italic,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDots) ...[
          DotsTypingIndicator(
            color: widget.dotColor ?? cs.primary,
            dotSize: widget.dotSize,
            gap: widget.dotGap,
          ),
          const SizedBox(width: 8),
        ],
        AnimatedBuilder(
          animation: _textAnimation,
          builder: (context, child) {
            final displayText = widget.text.substring(0, _textAnimation.value);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayText,
                  style: baseTextStyle,
                ),
                // 闪烁的光标
                if (_textAnimation.value < widget.text.length)
                  Container(
                    width: 2,
                    height: 16,
                    color: baseTextStyle.color,
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fade(begin: 1.0, end: 0.0, duration: 500.ms),
              ],
            );
          },
        ),
      ],
    );
  }
}