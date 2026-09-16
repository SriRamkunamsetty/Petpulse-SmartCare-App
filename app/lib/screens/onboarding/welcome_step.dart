import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/onboarding_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PpColors.accent800, PpColors.accent900],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.pets_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 18),
          Text('PetPulse', style: ppHeading(size: 34, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            "Smart care for your pet — even when you're away.",
            textAlign: TextAlign.center,
            style:
                ppBody(size: 14, color: Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => context.read<OnboardingState>().goBasics(),
                child: Center(
                  child: Text('Get Started',
                      style: ppHeading(size: 15, color: PpColors.accent800)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
