import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/onboarding_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/pp_button.dart';

class PairingStep extends StatelessWidget {
  const PairingStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ob = context.watch<OnboardingState>();
    return Column(
      children: [
        Text('Connect your feeder',
            style: ppHeading(size: 24), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'Make sure your PetPulse Feeder is powered on and nearby.',
          textAlign: TextAlign.center,
          style: ppBody(size: 13, color: Colors.black.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 20),
        switch (ob.pairState) {
          ObPairState.idle ||
          ObPairState.searching =>
            _Searching(onTrouble: ob.giveUpPairing),
          ObPairState.failed => _Failed(onRetry: ob.goPairing),
          ObPairState.found => _Found(
              name: ob.pairedDevice?.name ?? 'PetPulse Feeder',
              onConnect: ob.connectDevice),
          ObPairState.connected => const _Connected(),
        },
        const SizedBox(height: 20),
        PpButton(label: 'Continue', onPressed: ob.goDone),
        const SizedBox(height: 6),
        TextButton(
          onPressed: ob.skipPairing,
          child: Text('Skip for now',
              style: ppBody(size: 14, color: PpColors.accent)),
        ),
      ],
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching({required this.onTrouble});
  final VoidCallback onTrouble;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 60,
          height: 60,
          child:
              CircularProgressIndicator(strokeWidth: 4, color: PpColors.accent),
        ),
        const SizedBox(height: 16),
        Text('Searching for nearby devices…',
            style:
                ppBody(size: 13, color: Colors.black.withValues(alpha: 0.6))),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onTrouble,
          child: Text('Trouble connecting?',
              style: ppBody(size: 12, color: PpColors.accent)),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
              color: PpColors.neutral200, shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded, color: PpColors.neutral600),
        ),
        const SizedBox(height: 14),
        Text("Couldn't find your feeder",
            style: ppBody(size: 14, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text("Make sure it's powered on and within Wi-Fi range.",
            textAlign: TextAlign.center,
            style:
                ppBody(size: 12.5, color: Colors.black.withValues(alpha: 0.6))),
        const SizedBox(height: 14),
        PpButton(label: 'Try Again', height: 46, onPressed: onRetry),
      ],
    );
  }
}

class _Found extends StatelessWidget {
  const _Found({required this.name, required this.onConnect});
  final String name;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
              color: PpColors.accent100, shape: BoxShape.circle),
          child: const Icon(Icons.router_rounded, color: PpColors.accent700),
        ),
        const SizedBox(height: 14),
        Text('$name found', style: ppBody(size: 14, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        PpButton(label: 'Connect', onPressed: onConnect),
      ],
    );
  }
}

class _Connected extends StatelessWidget {
  const _Connected();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
              color: PpColors.accent2_100, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: PpColors.accent2_700),
        ),
        const SizedBox(height: 14),
        Text('Connected', style: ppBody(size: 14, weight: FontWeight.w700)),
      ],
    );
  }
}
