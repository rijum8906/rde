import 'package:flutter_test/flutter_test.dart';
import 'package:core/theme.dart';

void main() {
  group('seedsFromAccent', () {
    test('uses the accent as the primary seed', () {
      final seeds = seedsFromAccent('#0061a4');

      expect(seeds.primary, '#0061A4');
    });

    test('derives distinct supporting and contrasting families', () {
      final seeds = seedsFromAccent('#0061A4');

      expect(seeds.secondary, isNot(seeds.primary));
      expect(seeds.tertiary, isNot(seeds.primary));
      expect(seeds.secondary, isNot(seeds.tertiary));
      expect(seeds.secondary, matches(RegExp(r'^#[0-9A-F]{6}$')));
      expect(seeds.tertiary, matches(RegExp(r'^#[0-9A-F]{6}$')));
    });

    test('keeps the error family red', () {
      final seeds = seedsFromAccent('#0061A4');
      final red = int.parse(seeds.error.substring(1, 3), radix: 16);
      final green = int.parse(seeds.error.substring(3, 5), radix: 16);
      final blue = int.parse(seeds.error.substring(5, 7), radix: 16);

      expect(red, greaterThan(green));
      expect(red, greaterThan(blue));
    });

    test('falls back to the Material seed for malformed input', () {
      final seeds = seedsFromAccent('not-a-color');

      expect(seeds.primary, '#6750A4');
    });
  });
}
