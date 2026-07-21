// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:rde_settings/main.dart';

void main() {
  testWidgets('Settings app renders DashboardPage', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SettingsApp());

    // Verify that our scaffold contains the placeholder text (one in sidebar, one in page header).
    expect(find.text('Dashboard'), findsNWidgets(2));
  });
}
