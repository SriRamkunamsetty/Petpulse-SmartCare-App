// Smoke test: the app should build and show its initial loading state
// without throwing, before any network call to the backend resolves.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petpulse/main.dart';

void main() {
  testWidgets('PetPulseApp builds and shows the initial loading state',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PetPulseApp());

    // bootstrap() kicks off an async API call; before it resolves the app
    // should render its loading spinner rather than crash.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
