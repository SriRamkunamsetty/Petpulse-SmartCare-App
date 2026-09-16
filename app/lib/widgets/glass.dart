import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'pp_motion.dart';

/// Frosted "liquid glass" surface — `.pp-glass-btn` / `.pp-tabbar-glass`
/// in the prototype's inline CSS. `BackdropFilter` + a translucent tint +
/// an inset highlight to fake the shine.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.blur = 16,
    this.tint,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: tint ?? Colors.white.withValues(alpha: 0.55),
            borderRadius: borderRadius,
            border: Border.all(
                color: Colors.black.withValues(alpha: 0.06), width: 0.5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1AFFFFFF), blurRadius: 1, spreadRadius: 1),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Round glass icon button — `.pp-glass-btn` in the prototype.
class PpGlassButton extends StatelessWidget {
  const PpGlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 36,
    this.tint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: PpPressable(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(size),
          tint: tint,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Bottom tab bar — floating frosted pill, `.pp-tabbar` in the prototype.
class PpGlassBar extends StatelessWidget {
  const PpGlassBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: PpColors.neutral900.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(28),
        tint: Colors.white.withValues(alpha: 0.72),
        child: child,
      ),
    );
  }
}
