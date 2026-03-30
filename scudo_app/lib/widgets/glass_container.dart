import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.border,
    this.color,
  });

  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final Border? border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(20);
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: color != null
            ? null
            : AppColors.gradientGlass,
        color: color,
        border: border ??
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PulseRings extends StatelessWidget {
  const PulseRings({
    super.key,
    required this.animation,
    this.ringCount = 4,
    this.maxSize = 340,
    this.color,
  });

  final Animation<double> animation;
  final int ringCount;
  final double maxSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.red;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(ringCount, (i) {
            final phase = (animation.value + i / ringCount) % 1.0;
            final size = maxSize * (0.3 + phase * 0.7);
            final opacity = (1 - phase) * 0.25;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: c.withValues(alpha: opacity),
                  width: 1.5,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
