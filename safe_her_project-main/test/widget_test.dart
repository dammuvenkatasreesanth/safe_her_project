import 'package:flutter_test/flutter_test.dart';

import 'package:safe_her/main.dart';

void main() {
  testWidgets('Splash screen shows SafeHer branding', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeHerApp());
    await tester.pump();

    expect(find.byType(SafeHerApp), findsOneWidget);
  });
}
