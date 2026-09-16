import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/onboarding_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/pp_button.dart';
import '../../widgets/pp_card.dart';
import 'onboarding_flow.dart';

class SummaryStep extends StatelessWidget {
  const SummaryStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ob = context.watch<OnboardingState>();
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
              color: PpColors.accent2_100, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded,
              color: PpColors.accent2_700, size: 28),
        ),
        const SizedBox(height: 16),
        Text("You're all set!", style: ppHeading(size: 24)),
        const SizedBox(height: 4),
        Text("Here's what we've got",
            style:
                ppBody(size: 13, color: Colors.black.withValues(alpha: 0.55))),
        const SizedBox(height: 18),
        PpCard(
          elevation: PpCardElevation.sm,
          child: Column(
            children: [
              _Row('Name', ob.effectivePetName),
              _Row('Breed', ob.effectiveBreed),
              _Row('Age', '${ob.ageValue} ${ob.ageUnit}'),
              _Row('Weight', '${ob.weightValue}${ob.weightUnit}'),
              _Row('Health', ob.healthSummary),
              _Row('Feeder', ob.deviceSummary),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FinishButton(),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  ppBody(size: 13, color: Colors.black.withValues(alpha: 0.6))),
          Text(value, style: ppBody(size: 13, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FinishButton extends StatefulWidget {
  @override
  State<_FinishButton> createState() => _FinishButtonState();
}

class _FinishButtonState extends State<_FinishButton> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return PpButton(
      label: _saving ? 'Setting up…' : 'Go to Dashboard',
      height: 52,
      onPressed: _saving
          ? null
          : () async {
              setState(() => _saving = true);
              try {
                await completeOnboarding(context);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "Couldn't save your pet's profile — check your connection and try again.")),
                  );
                }
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
    );
  }
}
