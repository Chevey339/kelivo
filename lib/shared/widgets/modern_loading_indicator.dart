import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// 现代化的加载指示器，支持多种风格
enum LoadingStyle {
  wave,        // 波浪效果
  pulse,       // 脉冲效果  
  morph,       // 变形效果
  gradient,    // 渐变效果
  orbit,       // 轨道效果
}

class ModernLoadingIndicator extends StatefulWidget {
  const ModernLoadingIndicator({
    super.key,
    this.style = LoadingStyle.wave,
    this.size = 40.0,
    this.color,
    this.text,
    this.textStyle,
  });

  final LoadingStyle style;
  final double size;
  final Color? color;
  final String? text;
  final TextStyle? textStyle;

  @override
  State<ModernLoadingIndicator> createState() => _ModernLoadingIndicatorState();
}

class _ModernLoadingIndicatorState extends State<ModernLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _textController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    
    Widget loadingWidget;
    switch (widget.style) {
      case LoadingStyle.wave:
        loadingWidget = _buildWaveLoader(color);
        break;
      case LoadingStyle.pulse:
        loadingWidget = _buildPulseLoader(color);
        break;
      case LoadingStyle.morph:
        loadingWidget = _buildMorphLoader(color);
        break;
      case LoadingStyle.gradient:
        loadingWidget = _buildGradientLoader(color);
        break;
      case LoadingStyle.orbit:
        loadingWidget = _buildOrbitLoader(color);
        break;
    }

    if (widget.text != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loadingWidget,
          const SizedBox(height: 12),
          _buildAnimatedText(),
        ],
      );
    }

    return loadingWidget;
  }

  Widget _buildAnimatedText() {
    final cs = Theme.of(context).colorScheme;
    final style = widget.textStyle ?? TextStyle(
      fontSize: 14,
      color: cs.onSurface.withOpacity(0.6),
      fontStyle: FontStyle.italic,
    );

    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        final progress = _textController.value;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                style.color!.withOpacity(0.3),
                style.color!,
                style.color!.withOpacity(0.3),
              ],
              stops: [
                (progress - 0.3).clamp(0.0, 1.0),
                progress.clamp(0.0, 1.0),
                (progress + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Text(widget.text!, style: style),
        );
      },
    );
  }

  Widget _buildWaveLoader(Color color) {
    return SizedBox(
      width: widget.size,
      height: widget.size / 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final delay = index * 0.1;
              final progress = ((_controller.value + delay) % 1.0);
              final height = math.sin(progress * math.pi) * (widget.size / 2);
              
              return Container(
                width: widget.size / 8,
                height: height.abs(),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3 + 0.7 * progress),
                  borderRadius: BorderRadius.circular(widget.size / 16),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildPulseLoader(Color color) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 0.5 + 0.5 * math.sin(_controller.value * 2 * math.pi);
          final opacity = 0.3 + 0.7 * (1 - _controller.value);
          
          return Stack(
            alignment: Alignment.center,
            children: [
              // 外圈
              Transform.scale(
                scale: 1.0 + _controller.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(opacity * 0.5),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // 内圈
              Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size * 0.6,
                  height: widget.size * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMorphLoader(Color color) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final borderRadius = BorderRadius.circular(
            widget.size * (0.1 + 0.4 * math.sin(progress * 2 * math.pi)),
          );
          
          return Transform.rotate(
            angle: progress * 2 * math.pi,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withOpacity(0.5),
                  ],
                  transform: GradientRotation(progress * 2 * math.pi),
                ),
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradientLoader(Color color) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  color.withOpacity(0.0),
                  color.withOpacity(0.5),
                  color,
                  color.withOpacity(0.5),
                  color.withOpacity(0.0),
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                transform: GradientRotation(_controller.value * 2 * math.pi),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrbitLoader(Color color) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: List.generate(3, (index) {
              final angle = _controller.value * 2 * math.pi + (index * 2 * math.pi / 3);
              final radius = widget.size * 0.35;
              
              return Transform.translate(
                offset: Offset(
                  radius * math.cos(angle),
                  radius * math.sin(angle),
                ),
                child: Container(
                  width: widget.size * 0.15,
                  height: widget.size * 0.15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.6 + 0.4 * math.sin(angle)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// 紧凑版的现代加载指示器（用于行内显示）
class CompactModernLoader extends StatelessWidget {
  const CompactModernLoader({
    super.key,
    this.text = '',
    this.style = LoadingStyle.wave,
    this.color,
    this.height = 20,
  });

  final String text;
  final LoadingStyle style;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.primary;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: ModernLoadingIndicator(
            style: style,
            size: height,
            color: effectiveColor,
          ),
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(width: 8),
          // Android 上禁用 shimmer 效果以避免双重渲染问题
          isAndroid
            ? Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
                duration: 2000.ms,
                color: effectiveColor.withOpacity(0.1),
              ),
        ],
      ],
    );
  }
}
