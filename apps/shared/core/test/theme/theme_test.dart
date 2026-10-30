import 'package:core/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes shorthand theme colors', () {
    expect(ThemeColor.tryParse('#abc')?.value, '#AABBCC');
    expect(ThemeColor.tryParse('bad-color'), isNull);
  });

  test('parses appearance and contrast values from the service', () {
    expect(AppearanceMode.fromDbus('LIGHT'), AppearanceMode.light);
    expect(ContrastLevel.fromDbus('high'), ContrastLevel.high);
    expect(ContrastLevel.fromDbus('future-mode'), ContrastLevel.normal);
  });

  test('derives distinct dynamic seeds from an accent', () {
    final seeds = seedsFromAccent('#0061a4');

    expect(seeds.primary, '#0061A4');
    expect(seeds.secondary, isNot(seeds.primary));
    expect(seeds.tertiary, isNot(seeds.primary));
    expect(seeds.error, matches(RegExp(r'^#[0-9A-F]{6}$')));
  });
}
