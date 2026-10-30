import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:core/theme.dart';

/// Reduces a wallpaper to the four seed colors of the dynamic theme.
///
/// The image is bucketed into 5-bit RGB cells, ranked by population, and the
/// most populated colors that stay visually distinguishable are used as the
/// primary, secondary, tertiary, and error seeds. Missing families are derived
/// from the primary hue so a flat or monochrome wallpaper still yields a
/// complete palette.
class WallpaperPaletteExtractor {
  const WallpaperPaletteExtractor();

  /// Downsampled edge used while decoding, which is enough for color ranking.
  static const int _decodeEdge = 96;

  /// Smallest RGB distance two extracted seeds must have.
  static const int _minimumSeedDistance = 48;

  /// Default seeds used when the image has no opaque pixels.
  static const DynamicSeeds _fallback = DynamicSeeds.fallback;

  /// Decodes [bytes] and extracts the seeds.
  ///
  /// # Errors
  /// Throws a [FormatException] when the image cannot be decoded.
  Future<DynamicSeeds> fromImageBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: _decodeEdge,
      targetHeight: _decodeEdge,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        throw const FormatException('the wallpaper could not be decoded');
      }
      return fromRgba(data.buffer.asUint8List());
    } finally {
      image.dispose();
      codec.dispose();
    }
  }

  /// Extracts the seeds from raw RGBA pixels.
  ///
  /// # Parameters
  /// - [pixels]: four bytes per pixel (`r`, `g`, `b`, `a`)
  ///
  /// # Returns
  /// The four seeds. Fully transparent pixels are ignored.
  DynamicSeeds fromRgba(Uint8List pixels) {
    // Step 1: Bucket the image into 5-bit cells and average each cell.
    final buckets = <int, _ColorBucket>{};
    for (var index = 0; index + 3 < pixels.length; index += 4) {
      if (pixels[index + 3] < 128) {
        continue;
      }
      final key =
          ((pixels[index] >> 3) << 10) |
          ((pixels[index + 1] >> 3) << 5) |
          (pixels[index + 2] >> 3);
      buckets
          .putIfAbsent(key, _ColorBucket.new)
          .add(pixels[index], pixels[index + 1], pixels[index + 2]);
    }

    if (buckets.isEmpty) {
      return _fallback;
    }

    // Step 2: Rank the cells by how much of the image they cover.
    final ranked = buckets.values.toList()
      ..sort((left, right) => right.count.compareTo(left.count));

    // Step 3: Keep the most populated colors that stay far enough apart.
    final picked = <int>[];
    for (final bucket in ranked) {
      final color = bucket.rgb;
      final distinct = picked.every(
        (existing) => _distance(existing, color) >= _minimumSeedDistance,
      );
      if (!distinct) {
        continue;
      }
      picked.add(color);
      if (picked.length == 4) {
        break;
      }
    }

    // Step 4: Derive the families the image did not provide.
    final primary = picked.isNotEmpty ? picked[0] : 0x4285F4;
    final secondary = picked.length > 1 ? picked[1] : _rotateHue(primary, 60);
    final tertiary = picked.length > 2 ? picked[2] : _rotateHue(primary, -60);
    final error = picked.length > 3 ? picked[3] : 0xBA1A1A;

    return DynamicSeeds(
      primary: _hex(primary),
      secondary: _hex(secondary),
      tertiary: _hex(tertiary),
      error: _hex(error),
    );
  }

  /// Squared RGB distance, which is enough to compare relative similarity.
  static int _distance(int left, int right) {
    final dr = ((left >> 16) & 0xFF) - ((right >> 16) & 0xFF);
    final dg = ((left >> 8) & 0xFF) - ((right >> 8) & 0xFF);
    final db = (left & 0xFF) - (right & 0xFF);
    return dr * dr + dg * dg + db * db;
  }

  /// Rotates [rgb] by [degrees] while keeping its saturation and lightness.
  static int _rotateHue(int rgb, double degrees) {
    final color = HSLColor.fromColor(ui.Color(0xFF000000 | rgb));
    final hue = (color.hue + degrees) % 360;
    return color.withHue(hue < 0 ? hue + 360 : hue).toColor().toARGB32() &
        0xFFFFFF;
  }

  /// Formats a packed RGB value as uppercase `#RRGGBB`.
  static String _hex(int rgb) {
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

/// Accumulates the pixels of one 5-bit color cell.
class _ColorBucket {
  int count = 0;
  int _red = 0;
  int _green = 0;
  int _blue = 0;

  /// Adds one pixel to the cell.
  void add(int red, int green, int blue) {
    count++;
    _red += red;
    _green += green;
    _blue += blue;
  }

  /// Average color of the cell as packed RGB.
  int get rgb =>
      ((_red ~/ count) << 16) | ((_green ~/ count) << 8) | (_blue ~/ count);
}
