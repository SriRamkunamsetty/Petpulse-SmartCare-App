import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/onboarding/onboarding_flow.dart';
import 'screens/root_shell.dart';
import 'services/api_service.dart';
import 'state/app_state.dart';
import 'state/onboarding_state.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

void main() {
  runApp(const PetPulseApp());
}

class PetPulseApp extends StatelessWidget {
  const PetPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<AppState>(
          create: (context) =>
              AppState(context.read<ApiService>())..bootstrap(),
        ),
        ChangeNotifierProvider<OnboardingState>(
          create: (context) => OnboardingState(context.read<ApiService>()),
        ),
      ],
      child: MaterialApp(
        title: 'PetPulse',
        debugShowCheckedModeBanner: false,
        theme: buildPpTheme(),
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.bootstrapping) {
      return Scaffold(
        backgroundColor: PpColors.bg,
        body: Center(
          child: app.isWakingCloud
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: PpColors.accent),
                      const SizedBox(height: 18),
                      Text('Waking up your feeder\'s server…',
                          style: ppHeading(size: 16),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text(
                        'The free-tier server sleeps when idle — this can\n'
                        'take up to a minute the first time.',
                        textAlign: TextAlign.center,
                        style: ppBody(
                            size: 13,
                            color: PpColors.text.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(color: PpColors.accent),
        ),
      );
    }
    if (app.bootstrapError != null) {
      return Scaffold(
        backgroundColor: PpColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 40, color: PpColors.neutral600),
                const SizedBox(height: 12),
                Text("Couldn't reach PetPulse",
                    style: ppHeading(size: 18), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  app.bootstrapError!,
                  textAlign: TextAlign.center,
                  style: ppBody(
                      size: 13, color: PpColors.text.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.read<AppState>().bootstrap(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!app.onboarded) return const OnboardingFlow();
    return const RootShell();
  }
}
