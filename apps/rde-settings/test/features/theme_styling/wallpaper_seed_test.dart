import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/wallpaper/kde_wallpaper_source.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/wallpaper/wallpaper_palette_extractor.dart';

void main() {
  group('WallpaperPaletteExtractor', () {
    const extractor = WallpaperPaletteExtractor();

    test('picks four dominant colors from a four-quadrant image', () {
      final pixels = _image(
        width: 40,
        height: 40,
        colorAt: (x, y) {
          if (x < 20 && y < 20) {
            return const [0x67, 0x50, 0xA4]; // purple
          }
          if (x >= 20 && y < 20) {
            return const [0x00, 0x6A, 0x6A]; // teal
          }
          if (x < 20) {
            return const [0xB5, 0x27, 0x00]; // terracotta
          }
          return const [0x00, 0x6E, 0x3C]; // emerald
        },
      );

      final seeds = extractor.fromRgba(pixels);

      expect(
        {seeds.primary, seeds.secondary, seeds.tertiary, seeds.error},
        {'#6750A4', '#006A6A', '#B52700', '#006E3C'},
      );
    });

    test('derives the missing families from a monochrome image', () {
      final pixels = _image(
        width: 8,
        height: 8,
        colorAt: (_, _) => const [0x67, 0x50, 0xA4],
      );

      final seeds = extractor.fromRgba(pixels);

      expect(seeds.primary, '#6750A4');
      // Secondary and tertiary rotate the primary hue, and error stays the
      // Material red instead of reusing the accent.
      expect(seeds.secondary, isNot(seeds.primary));
      expect(seeds.tertiary, isNot(seeds.primary));
      expect(seeds.error, '#BA1A1A');
    });

    test('ignores transparent pixels', () {
      final pixels = Uint8List.fromList(List<int>.filled(16, 0));

      final seeds = extractor.fromRgba(pixels);

      expect(seeds.primary, '#4285F4');
    });
  });

  group('KdeWallpaperSource.parseWallpaperPath', () {
    test('returns a plain path unchanged', () {
      expect(
        KdeWallpaperSource.parseWallpaperPath('/home/user/wall.png\n'),
        '/home/user/wall.png',
      );
    });

    test('unquotes the printed value', () {
      expect(
        KdeWallpaperSource.parseWallpaperPath('"/home/user/my wall.png"'),
        '/home/user/my wall.png',
      );
    });

    test('converts a file URI to a path', () {
      expect(
        KdeWallpaperSource.parseWallpaperPath(
          'file:///home/user/Pictures/wall%20paper.png',
        ),
        '/home/user/Pictures/wall paper.png',
      );
    });

    test('returns null when the shell printed nothing', () {
      expect(KdeWallpaperSource.parseWallpaperPath('  \n'), isNull);
      expect(KdeWallpaperSource.parseWallpaperPath('""'), isNull);
    });
  });
}

/// Builds a raw RGBA buffer from a per-pixel color callback.
Uint8List _image({
  required int width,
  required int height,
  required List<int> Function(int x, int y) colorAt,
}) {
  final pixels = Uint8List(width * height * 4);
  var index = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final color = colorAt(x, y);
      pixels[index++] = color[0];
      pixels[index++] = color[1];
      pixels[index++] = color[2];
      pixels[index++] = 0xFF;
    }
  }
  return pixels;
}
