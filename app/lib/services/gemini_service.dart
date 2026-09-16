import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feeding_event.dart';
import '../models/pet.dart';
import '../models/schedule_entry.dart';
import '../models/telemetry.dart';
import 'api_exception.dart';

/// Calls the real Gemini API (Google AI Studio) to turn the pet's profile
/// and live PetPulse data into care recommendations.
///
/// The API key is provided by the user (get one free at
/// aistudio.google.com), stored only in this device's local storage via
/// [SharedPreferences], and sent directly from the device to Google's
/// endpoint — it never passes through PetPulse's own backend.
///
/// Uses the `generateContent` REST endpoint, which has been stable Gemini
/// API surface for a while. If Google renames/retires the model in
/// [defaultModel], update that one constant.
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const defaultModel = 'gemini-2.5-flash';
  static const _prefsKey = 'pp_gemini_api_key';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, key);
  }

  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<String> getRecommendations({
    required Pet pet,
    required Telemetry telemetry,
    required List<ScheduleEntry> schedule,
    required List<DayIntake> weekBars,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const ApiException('Add your Gemini API key first.');
    }
    final prompt = _buildPrompt(
      pet: pet,
      telemetry: telemetry,
      schedule: schedule,
      weekBars: weekBars,
    );
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$defaultModel:generateContent?key=$apiKey',
    );
    http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ApiException('Gemini request timed out.');
    } catch (e) {
      throw ApiException('Network error: $e');
    }

    if (res.statusCode >= 400) {
      final message = _extractErrorMessage(res.body) ?? res.body;
      throw ApiException('Gemini API error (${res.statusCode}): $message',
          statusCode: res.statusCode);
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const ApiException(
          'Gemini returned no response — it may have blocked the prompt.');
    }
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw const ApiException('Gemini returned an empty response.');
    }
    final text = (parts.first['text'] as String?)?.trim();
    if (text == null || text.isEmpty) {
      throw const ApiException('Gemini returned an empty response.');
    }
    return text;
  }

  String? _extractErrorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['error'] as Map<String, dynamic>?)?['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _buildPrompt({
    required Pet pet,
    required Telemetry telemetry,
    required List<ScheduleEntry> schedule,
    required List<DayIntake> weekBars,
  }) {
    final scheduleLines = schedule.isEmpty
        ? '  (no feeding schedule set)'
        : schedule
            .map((e) =>
                '  - ${e.day} ${e.time}: ${e.grams}g${e.enabled ? '' : ' (disabled)'}')
            .join('\n');
    final historyLine = weekBars.isEmpty
        ? '(no history yet)'
        : weekBars.map((b) => '${b.label}: ${b.grams}g').join(', ');

    return '''
You are a veterinary-informed pet care assistant inside PetPulse, a smart pet feeder app. Give the owner clear, practical recommendations based on the real data below. Be specific to this pet, not generic. Flag anything that looks like it might need a vet's attention, but don't diagnose. Keep it to about 150-250 words, plain text, short paragraphs or "-" bullet points (no markdown headers or bold).

Pet profile:
- Name: ${pet.name.isEmpty ? 'Unknown' : pet.name}
- Breed: ${pet.breed.isEmpty ? 'Unknown' : pet.breed}
- Age: ${pet.ageValue} ${pet.ageUnit}
- Weight: ${pet.weightValue} ${pet.weightUnit}
- Health conditions: ${pet.healthSummary}
- Owner notes: ${pet.notes.isEmpty ? '(none)' : pet.notes}

Current feeder status:
- Bowl weight right now: ${telemetry.bowlWeightGrams.toStringAsFixed(1)}g
- Hopper food level: ${telemetry.foodLevelPct}%
- Device connectivity: ${telemetry.connectivity.name}

Feeding schedule:
$scheduleLines

Grams dispensed per day, last 7 days: $historyLine

Cover: whether the portion sizes and feeding frequency look appropriate for this pet's profile, any adjustment worth making to the schedule, and anything in the food-level/intake trend worth flagging.
''';
  }
}
