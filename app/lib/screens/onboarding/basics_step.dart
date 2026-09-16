import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/onboarding_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_button.dart';
import '../../widgets/pp_card.dart';

class BasicsStep extends StatelessWidget {
  const BasicsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ob = context.watch<OnboardingState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tell us about your pet', style: ppHeading(size: 24)),
        const SizedBox(height: 4),
        Text('Helps PetPulse personalize feeding & alerts.',
            style:
                ppBody(size: 13, color: Colors.black.withValues(alpha: 0.55))),
        const SizedBox(height: 20),
        PpInput(
          label: 'Pet name',
          placeholder: 'e.g. Milo',
          onChanged: ob.setName,
        ),
        const SizedBox(height: 14),
        PpInput(
          label: 'Breed',
          placeholder: 'e.g. Corgi',
          onChanged: ob.setBreed,
        ),
        const SizedBox(height: 14),
        PpCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Age', style: ppBody(size: 13, weight: FontWeight.w600)),
              Row(
                children: [
                  PpStepper(
                      value: '${ob.ageValue}',
                      onInc: ob.incAge,
                      onDec: ob.decAge),
                  const SizedBox(width: 10),
                  PpSegmented(
                    options: const ['yrs', 'mos'],
                    value: ob.ageUnit,
                    onChanged: ob.setAgeUnit,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PpCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weight', style: ppBody(size: 13, weight: FontWeight.w600)),
              Row(
                children: [
                  PpStepper(
                      value: '${ob.weightValue}',
                      onInc: ob.incWeight,
                      onDec: ob.decWeight),
                  const SizedBox(width: 10),
                  PpSegmented(
                    options: const ['kg', 'lb'],
                    value: ob.weightUnit,
                    onChanged: ob.setWeightUnit,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PpButton(
          label: 'Continue',
          onPressed: ob.isBasicsInvalid ? null : ob.goHealth,
        ),
      ],
    );
  }
}
