import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class AppGradientBackground extends StatelessWidget {
  final Widget child;
  const AppGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          child: ValueListenableBuilder<bool>(
            valueListenable: StorageService.reducedEffects,
            builder: (_, reduced, _) => _Backdrop(reduced: reduced),
          ),
        ),
        child,
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  final bool reduced;
  const _Backdrop({required this.reduced});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A0A0A),
            AppColors.darkBackground,
            Color(0xFF0A0A14),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: reduced
          ? const SizedBox.expand()
          : Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -80,
                  child: _GlowBlob(
                    color:
                        AppColors.stravaOrange.withValues(alpha: 0.18),
                    size: 320,
                  ),
                ),
                Positioned(
                  bottom: -140,
                  left: -100,
                  child: _GlowBlob(
                    color: const Color(0xFF4A1A4F).withValues(alpha: 0.22),
                    size: 360,
                  ),
                ),
              ],
            ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
