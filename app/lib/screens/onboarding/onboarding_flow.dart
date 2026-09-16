import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/onboarding_state.dart';
import '../../theme/tokens.dart';
import 'basics_step.dart';
import 'health_step.dart';
import 'pairing_step.dart';
import 'summary_step.dart';
import 'welcome_step.dart';

/// Welcome -> Pet basics -> Health -> Feeder pairing -> Summary, matching
/// the `isOnboarding` / `obStep` branches in the .dc.html prototype.
class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PpColors.bg,
      body: Consumer<OnboardingState>(
        builder: (context, ob, _) {
          if (ob.step == ObStep.welcome) return const WelcomeStep();
          return SafeArea(
            child: Column(
              children: [
                _StepHeader(step: ob.step, onBack: ob.back),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    child: switch (ob.step) {
                      ObStep.basics => const BasicsStep(),
                      ObStep.health => const HealthStep(),
                      ObStep.pairing => const PairingStep(),
                      ObStep.done => const SummaryStep(),
                      ObStep.welcome => const SizedBox.shrink(),
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.onBack});
  final ObStep step;
  final VoidCallback onBack;

  static const _steps = [
    ObStep.basics,
    ObStep.health,
    ObStep.pairing,
    ObStep.done
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = _steps.indexOf(step);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _BackButton(onTap: onBack),
          const SizedBox(width: 10),
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 20,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= activeIndex
                        ? const Color(0xFFC67139)
                        : const Color(0xFFDCD3C4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.white.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
        ),
      ),
    );
  }
}

/// Called from [SummaryStep]'s "Go to Dashboard" — bridges onboarding
/// state into [AppState] and persists the pet profile via the API.
Future<void> completeOnboarding(BuildContext context) async {
  final ob = context.read<OnboardingState>();
  final app = context.read<AppState>();
  await app.finishOnboarding(ob.buildPet());
}
