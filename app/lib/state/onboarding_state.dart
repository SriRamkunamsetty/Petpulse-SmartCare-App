import 'dart:async';

import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/pet.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';

enum ObStep { welcome, basics, health, pairing, done }

enum ObPairState { idle, searching, found, failed, connected }

const kHealthOptions = [
  'None',
  'Diabetes',
  'Obesity',
  'Food allergies',
  'Arthritis',
  'Kidney disease',
];

/// Drives the Welcome -> Pet basics -> Health -> Feeder pairing -> Summary
/// flow from the .dc.html prototype. Pairing now hits the real
/// `/api/v1/devices/pair/*` endpoints instead of a `setTimeout`.
class OnboardingState extends ChangeNotifier {
  OnboardingState(this._api);

  final ApiService _api;

  ObStep step = ObStep.welcome;
  static const _steps = [
    ObStep.basics,
    ObStep.health,
    ObStep.pairing,
    ObStep.done
  ];

  String name = '';
  String breed = '';
  int ageValue = 2;
  String ageUnit = 'yrs';
  int weightValue = 12;
  String weightUnit = 'kg';
  final Set<String> health = {};
  String notes = '';

  ObPairState pairState = ObPairState.idle;
  Device? pairedDevice;
  String? _pairSessionId;
  Timer? _pairPollTimer;

  bool get isBasicsInvalid => name.trim().isEmpty;
  String get effectivePetName => name.trim().isEmpty ? 'Milo' : name.trim();
  String get effectiveBreed => breed.trim().isEmpty ? 'Corgi' : breed.trim();
  String get healthSummary =>
      health.isEmpty ? 'None reported' : health.join(', ');
  String get deviceSummary =>
      pairState == ObPairState.connected ? 'Connected' : 'Not connected yet';

  int get stepIndex => _steps.indexOf(step);

  void goBasics() {
    step = ObStep.basics;
    notifyListeners();
  }

  void goHealth() {
    step = ObStep.health;
    notifyListeners();
  }

  void goPairing() {
    step = ObStep.pairing;
    _beginPairing();
    notifyListeners();
  }

  void goDone() {
    step = ObStep.done;
    notifyListeners();
  }

  void back() {
    final i = stepIndex;
    if (i <= 0) {
      step = ObStep.welcome;
    } else {
      step = _steps[i - 1];
    }
    notifyListeners();
  }

  void setName(String v) {
    name = v;
    notifyListeners();
  }

  void setBreed(String v) {
    breed = v;
    notifyListeners();
  }

  void setNotes(String v) {
    notes = v;
    notifyListeners();
  }

  void incAge() {
    ageValue = (ageValue + 1).clamp(0, 30);
    notifyListeners();
  }

  void decAge() {
    ageValue = (ageValue - 1).clamp(0, 30);
    notifyListeners();
  }

  void setAgeUnit(String unit) {
    ageUnit = unit;
    notifyListeners();
  }

  void incWeight() {
    weightValue += 1;
    notifyListeners();
  }

  void decWeight() {
    weightValue = (weightValue - 1).clamp(1, 999);
    notifyListeners();
  }

  void setWeightUnit(String unit) {
    weightUnit = unit;
    notifyListeners();
  }

  void toggleHealth(String key) {
    if (key == 'None') {
      health.clear();
      health.add('None');
    } else {
      health.remove('None');
      if (health.contains(key)) {
        health.remove(key);
      } else {
        health.add(key);
      }
    }
    notifyListeners();
  }

  Future<void> _beginPairing() async {
    _pairPollTimer?.cancel();
    pairState = ObPairState.searching;
    notifyListeners();
    try {
      _pairSessionId = await _api.startPairing();
      _pollPairing();
    } on ApiException {
      pairState = ObPairState.failed;
      notifyListeners();
    }
  }

  void _pollPairing() {
    _pairPollTimer =
        Timer.periodic(const Duration(milliseconds: 700), (_) async {
      final sessionId = _pairSessionId;
      if (sessionId == null || pairState != ObPairState.searching) return;
      try {
        final status = await _api.getPairingStatus(sessionId);
        if (status.state == 'found' && status.device != null) {
          _pairPollTimer?.cancel();
          pairedDevice = status.device;
          pairState = ObPairState.found;
          notifyListeners();
        } else if (status.state == 'failed') {
          _pairPollTimer?.cancel();
          pairState = ObPairState.failed;
          notifyListeners();
        }
      } on ApiException {
        _pairPollTimer?.cancel();
        pairState = ObPairState.failed;
        notifyListeners();
      }
    });
  }

  /// User tapped "Trouble connecting?" while still searching.
  void giveUpPairing() {
    _pairPollTimer?.cancel();
    pairState = ObPairState.failed;
    notifyListeners();
  }

  Future<void> connectDevice() async {
    final sessionId = _pairSessionId;
    if (sessionId == null) return;
    try {
      final device = await _api.confirmPairing(sessionId);
      pairedDevice = device;
      pairState = ObPairState.connected;
      notifyListeners();
    } on ApiException {
      pairState = ObPairState.failed;
      notifyListeners();
    }
  }

  void skipPairing() {
    _pairPollTimer?.cancel();
    pairState = ObPairState.idle;
    step = ObStep.done;
    notifyListeners();
  }

  Pet buildPet() => Pet(
        name: effectivePetName,
        breed: effectiveBreed,
        ageValue: ageValue,
        ageUnit: ageUnit,
        weightValue: weightValue,
        weightUnit: weightUnit,
        healthConditions: health.toList(),
        notes: notes,
      );

  @override
  void dispose() {
    _pairPollTimer?.cancel();
    super.dispose();
  }
}
