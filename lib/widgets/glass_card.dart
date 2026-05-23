import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
    this.blur = 8,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );
    final borderShape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: BorderSide(
        color: Colors.white.withValues(alpha: 0.08),
        width: 1,
      ),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: StorageService.reducedEffects,
      builder: (_, reduced, _) {
        final body = DecoratedBox(
          decoration: ShapeDecoration(
            color: reduced
                ? Colors.white.withValues(alpha: 0.04)
                : (color ?? Colors.white.withValues(alpha: 0.06)),
            shape: borderShape,
          ),
          child: Padding(padding: padding, child: child),
        );
        return ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: reduced
              ? body
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: body,
                ),
        );
      },
    );
  }
}
