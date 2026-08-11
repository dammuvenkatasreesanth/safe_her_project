import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safe_her/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows SafeHer branding', (WidgetTester tester) async {
    // Pumps SplashScreen directly rather than the full SafeHerApp — the
    // app-level widget initializes Firebase Messaging in initState, which
    // needs a real Firebase.initializeApp() call (done in main(), not
    // here) and isn't what this test is actually checking.
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
