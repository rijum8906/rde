//! # Shell Panel Test
//!
//! Verifies that the rewritten shell renders its top panel.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_shell/app.dart';

void main() {
  testWidgets('renders the top panel', (WidgetTester tester) async {
    await tester.pumpWidget(const RdeShellApp());
    await tester.pump();

    expect(find.text('RDE'), findsOneWidget);
    expect(find.text('Desktop'), findsOneWidget);

    // Unmount so the panel's clock timer is cancelled.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
