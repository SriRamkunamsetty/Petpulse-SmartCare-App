import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A tappable surface that scales down on press and springs back on
/// release, with a light haptic tick — the tactile "everything responds"
/// feel iOS interactions are built around. Replaces raw `Material` +
/// `InkWell` wherever something is tappable, so every button/card/icon in
/// the app shares the same press feel instead of a flat, static tap.
class PpPressable extends StatefulWidget {
  const PpPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.color = Colors.transparent,
    this.borderRadius,
    this.customBorder,
    this.pressedScale = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final double pressedScale;
  final bool haptic;

  @override
  State<PpPressable> createState() => _PpPressableState();
}

class _PpPressableState extends State<PpPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.color,
      shape: widget.customBorder,
      borderRadius: widget.customBorder == null ? widget.borderRadius : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        customBorder: widget.customBorder,
        borderRadius: widget.customBorder == null ? widget.borderRadius : null,
        onHighlightChanged: widget.onTap == null
            ? null
            : (value) {
                setState(() => _pressed = value);
                if (value && widget.haptic) {
                  HapticFeedback.selectionClick();
                }
              },
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1.0,
          duration: Duration(milliseconds: _pressed ? 90 : 220),
          curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A small idle-bobbing paw print — used to soften empty/offline states
/// with a bit of personality instead of a bare static icon.
class PawMascot extends StatefulWidget {
  const PawMascot({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  State<PawMascot> createState() => _PawMascotState();
}

class _PawMascotState extends State<PawMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -4 * t),
          child: Transform.rotate(angle: (t - 0.5) * 0.12, child: child),
        );
      },
      child: Icon(Icons.pets_rounded, size: widget.size, color: widget.color),
    );
  }
}

/// Smoothly tweens a numeric telemetry readout to its new value instead of
/// snapping on every poll — on first build it also counts up from 0, which
/// reads as a deliberate little flourish rather than a placeholder flicker.
class PpAnimatedNumber extends StatelessWidget {
  const PpAnimatedNumber({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 600),
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => builder(context, v),
    );
  }
}
