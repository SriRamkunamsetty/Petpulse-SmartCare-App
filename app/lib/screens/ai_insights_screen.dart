import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_exception.dart';
import '../services/gemini_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/pp_button.dart';
import '../widgets/pp_card.dart';

/// Pushed from the Home screen header — not a tab, to keep the prototype's
/// 5-icon tab bar intact. Calls the real Gemini API with the pet's profile
/// plus live telemetry/schedule/history for genuinely data-driven
/// recommendations, not canned text.
class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  final _gemini = GeminiService();
  final _keyController = TextEditingController();

  String? _apiKey;
  bool _loadingKey = true;
  bool _requesting = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadKey() async {
    final key = await _gemini.getApiKey();
    if (!mounted) return;
    setState(() {
      _apiKey = key;
      _loadingKey = false;
    });
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    await _gemini.setApiKey(key);
    if (!mounted) return;
    setState(() => _apiKey = key);
    _requestRecommendations();
  }

  Future<void> _changeKey() async {
    await _gemini.clearApiKey();
    if (!mounted) return;
    setState(() {
      _apiKey = null;
      _result = null;
      _error = null;
    });
  }

  Future<void> _requestRecommendations() async {
    final app = context.read<AppState>();
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final result = await _gemini.getRecommendations(
        pet: app.pet,
        telemetry: app.telemetry,
        schedule: app.schedule,
        weekBars: app.weekBars,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: PpColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('AI Insights', style: ppHeading(size: 24)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'Gemini-powered recommendations from ${app.pet.name.isEmpty ? "your pet" : app.pet.name}\'s real profile and feeder data.',
                  style: ppBody(
                      size: 13, color: PpColors.text.withValues(alpha: 0.55)),
                ),
              ),
              const SizedBox(height: 18),
              if (_loadingKey)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: PpColors.accent),
                ))
              else if (_apiKey == null)
                _ApiKeyForm(controller: _keyController, onSave: _saveKey)
              else ...[
                PpCard(
                  elevation: PpCardElevation.sm,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: PpColors.accent100,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: PpColors.accent700, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                app.pet.name.isEmpty
                                    ? 'Your pet'
                                    : app.pet.name,
                                style:
                                    ppBody(size: 14, weight: FontWeight.w700)),
                            PpCardMeta(
                                '${app.pet.breedWeightLine} · ${app.pet.healthSummary}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PpButton(
                  label: _requesting ? 'Thinking…' : 'Get Recommendations',
                  onPressed: _requesting ? null : _requestRecommendations,
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _changeKey,
                    child: Text('Change API key',
                        style: ppBody(size: 12, color: PpColors.accent)),
                  ),
                ),
                const SizedBox(height: 8),
                if (_error != null)
                  PpCard(
                    elevation: PpCardElevation.sm,
                    color: PpColors.accent100,
                    child: Text(_error!,
                        style: ppBody(size: 13, color: PpColors.accent800)),
                  ),
                if (_result != null)
                  PpCard(
                    elevation: PpCardElevation.sm,
                    child: Text(_result!, style: ppBody(size: 14)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiKeyForm extends StatelessWidget {
  const _ApiKeyForm({required this.controller, required this.onSave});
  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return PpCard(
      elevation: PpCardElevation.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect Gemini', style: ppHeading(size: 18)),
          const SizedBox(height: 4),
          Text(
            'Get a free API key at aistudio.google.com, then paste it below. '
            "It's stored only on this device and sent directly to Google — "
            "never through PetPulse's own backend.",
            style:
                ppBody(size: 12.5, color: PpColors.text.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 14),
          PpInput(
            label: 'Gemini API key',
            controller: controller,
            placeholder: 'AIza…',
          ),
          const SizedBox(height: 14),
          PpButton(label: 'Save & Get Recommendations', onPressed: onSave),
        ],
      ),
    );
  }
}
