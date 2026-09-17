// Kept deliberately minimal: SafeHerAdminApp itself needs Firebase.initializeApp()
// to have run (it's called in main(), not in the widget tree), which a plain
// widget test can't do without pulling in a Firebase mocking package this
// project doesn't otherwise need. This just checks the theme builds as
// expected — a real smoke test of the full app belongs in an integration
// test once the Firebase Web app is actually registered (see README.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher_admin/theme.dart';

void main() {
  test('buildAdminTheme uses the SafeHer brand color as its seed', () {
    final theme = buildAdminTheme();
    expect(theme.colorScheme.primary, AppColors.primary);
  });
}
