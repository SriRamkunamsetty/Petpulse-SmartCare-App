import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/onboarding_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/pp_button.dart';

class HealthStep extends StatelessWidget {
  const HealthStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ob = context.watch<OnboardingState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Any health conditions?', style: ppHeading(size: 24)),
        const SizedBox(height: 4),
        Text("Optional — helps us flag unusual feeding patterns.",
            style:
                ppBody(size: 13, color: Colors.black.withValues(alpha: 0.55))),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in kHealthOptions)
              _HealthChip(
                label: option,
                selected: ob.health.contains(option),
                onTap: () => ob.toggleHealth(option),
              ),
          ],
        ),
        const SizedBox(height: 16),
        PpInput(
          label: 'Anything else? (optional)',
          placeholder: 'e.g. sensitive stomach, on medication…',
          maxLines: 3,
          onChanged: ob.setNotes,
        ),
        const SizedBox(height: 12),
        PpButton(label: 'Continue', onPressed: ob.goPairing),
      ],
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PpColors.accent2_500 : PpColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: ppBody(
                size: 13, color: selected ? Colors.white : PpColors.text),
          ),
        ),
      ),
    );
  }
}
