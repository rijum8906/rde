import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/core/widgets/rde_slider.dart';

Future<void> _pumpSlider(
  WidgetTester tester,
  ValueChanged<double> onChanged,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: RdeSlider(
              value: 50,
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Sends one mouse wheel notch over the slider.
Future<void> _wheel(WidgetTester tester, double deltaY) async {
  final center = tester.getCenter(find.byType(RdeSlider));
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  pointer.hover(center);
  await tester.sendEventToBinding(
    pointer.scroll(Offset(0, deltaY)),
  );
}

void main() {
  testWidgets('one wheel notch moves a 0-100 volume by 5%', (tester) async {
    final changes = <double>[];
    await _pumpSlider(tester, changes.add);

    // Wheel up raises the volume.
    await _wheel(tester, -20);
    expect(changes, [55]);

    // Wheel down lowers it from the value the card now shows.
    await _wheel(tester, 20);
    expect(changes, [55, 45]);
  });
}
