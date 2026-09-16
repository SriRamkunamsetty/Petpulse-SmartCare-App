import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/app_theme.dart';
import 'pp_motion.dart';

enum PpButtonVariant { primary, secondary, ghost }

/// `.btn` family from styles.css — heading-font label, pill radius.
class PpButton extends StatelessWidget {
  const PpButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PpButtonVariant.primary,
    this.height = 50,
    this.block = true,
    this.fontSize = 15,
  });

  final String label;
  final VoidCallback? onPressed;
  final PpButtonVariant variant;
  final double height;
  final bool block;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final Color bg;
    final Color fg;
    Border? border;
    switch (variant) {
      case PpButtonVariant.primary:
        bg = PpColors.accent;
        fg = PpColors.bg;
        break;
      case PpButtonVariant.secondary:
        bg = Colors.transparent;
        fg = PpColors.text;
        border = Border.all(color: PpColors.divider);
        break;
      case PpButtonVariant.ghost:
        bg = Colors.transparent;
        fg = PpColors.accent;
        break;
    }
    final button = Opacity(
      opacity: disabled ? 0.45 : 1,
      child: PpPressable(
        onTap: onPressed,
        color: bg,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: border?.top ?? BorderSide.none,
        ),
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(label,
              style: ppHeading(size: fontSize, color: fg, letterSpacing: 0)),
        ),
      ),
    );
    if (!block) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// `−`/`+` stepper used for age, weight and portion controls.
class PpStepper extends StatelessWidget {
  const PpStepper({
    super.key,
    required this.value,
    required this.onInc,
    required this.onDec,
  });

  final String value;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBtn('−', onDec),
        SizedBox(
          width: 44,
          child: Text(value,
              textAlign: TextAlign.center, style: ppHeading(size: 16)),
        ),
        _stepBtn('+', onInc),
      ],
    );
  }

  Widget _stepBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PpPressable(
        color: PpColors.bg,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(child: Text(label, style: ppHeading(size: 16))),
      ),
    );
  }
}

/// `.seg` segmented control (e.g. yrs/mos, kg/lb, g/oz).
class PpSegmented extends StatelessWidget {
  const PpSegmented(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged});

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: PpColors.divider),
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opt in options)
            InkWell(
              onTap: () => onChanged(opt),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                color: opt == value ? PpColors.accent : Colors.transparent,
                child: Text(
                  opt,
                  style: ppBody(
                    size: 12,
                    weight: FontWeight.w600,
                    color: opt == value ? PpColors.bg : PpColors.text,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A toggle switch matching the prototype's hand-rolled pill switch.
class PpSwitch extends StatelessWidget {
  const PpSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? PpColors.accent2_500 : PpColors.neutral300,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 2,
                    offset: Offset(0, 1)),
              ]),
        ),
      ),
    );
  }
}

/// `.input` text field.
class PpInput extends StatelessWidget {
  const PpInput({
    super.key,
    required this.label,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                ppBody(size: 12, color: PpColors.text.withValues(alpha: 0.7))),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          style: ppBody(size: 14),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle:
                ppBody(size: 14, color: PpColors.text.withValues(alpha: 0.4)),
            filled: true,
            fillColor: PpColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              borderSide: BorderSide(color: PpColors.divider),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              borderSide: BorderSide(color: PpColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: const BorderSide(color: PpColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}
