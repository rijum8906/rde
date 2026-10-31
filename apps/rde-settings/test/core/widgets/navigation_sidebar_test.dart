import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/core/widgets/navigation_sidebar.dart';

/// Pumps the rail inside a window of [size] logical pixels.
Future<void> _pumpSidebar(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: NavigationSidebar(currentPath: '/dashboard')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a narrow window shows only the icons', (tester) async {
    await _pumpSidebar(tester, const Size(800, 600));

    // The label is gone, and the destination is still discoverable through the
    // tooltip that replaces it.
    expect(find.text('Dashboard'), findsNothing);
    expect(find.byTooltip('Dashboard'), findsOneWidget);
  });

  testWidgets('a wide window shows the labels again', (tester) async {
    await _pumpSidebar(tester, const Size(1440, 900));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byTooltip('Dashboard'), findsNothing);
  });
}
