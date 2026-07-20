import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/core/errors/rde_error.dart';

void main() {
  test('Test RdeError', () {
    /// Convert to UI-friendly format
    final err1 = RdeError('A test error', RdeErrorType.network);
    expect(err1.toUiMessage(), "Network Error: A test error");

    /// Convert to UI-friendly format
    final err2 = RdeError('A test error', RdeErrorType.device);
    expect(err2.toUiMessage(), "Device Error: A test error");
  });
}
