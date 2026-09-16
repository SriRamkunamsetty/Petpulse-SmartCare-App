import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/app_theme.dart';
import 'pp_motion.dart';

/// `.card` from styles.css — rounded surface with optional elevation.
class PpCard extends StatelessWidget {
  const PpCard({
    super.key,
    required this.child,
    this.elevation = PpCardElevation.none,
    this.color,
    this.padding = const EdgeInsets.all(PpSpace.s3),
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final PpCardElevation elevation;
  final Color? color;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(PpRadius.card);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? PpColors.surface,
        borderRadius: radius,
        boxShadow: switch (elevation) {
          PpCardElevation.none => null,
          PpCardElevation.sm => PpShadow.sm,
          PpCardElevation.md => PpShadow.md,
          PpCardElevation.lg => PpShadow.lg,
        },
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PpPressable(
      onTap: onTap,
      borderRadius: radius,
      pressedScale: 0.98,
      child: card,
    );
  }
}

enum PpCardElevation { none, sm, md, lg }

class PpCardKicker extends StatelessWidget {
  const PpCardKicker(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: ppBody(size: 10, weight: FontWeight.w700, color: PpColors.accent)
          .copyWith(letterSpacing: 1.1),
    );
  }
}

class PpCardMeta extends StatelessWidget {
  const PpCardMeta(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: ppBody(size: 11, color: PpColors.text.withValues(alpha: 0.5)));
  }
}

/// `.tag` from styles.css.
class PpTag extends StatelessWidget {
  const PpTag(this.text, {super.key, this.variant = PpTagVariant.neutral});
  final String text;
  final PpTagVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      PpTagVariant.accent => (PpColors.accent100, PpColors.accent800),
      PpTagVariant.accent2 => (PpColors.accent2_100, PpColors.accent2_800),
      PpTagVariant.neutral => (PpColors.neutral100, PpColors.neutral800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: ppBody(size: 11, weight: FontWeight.w600, color: fg)),
    );
  }
}

enum PpTagVariant { accent, accent2, neutral }
