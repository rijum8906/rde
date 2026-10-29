import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/wallpaper/kde_wallpaper_source.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/wallpaper/wallpaper_palette_extractor.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/wallpaper_seed_source.dart';

/// Extracts the dynamic seeds from the wallpaper Plasma currently displays.
class KdeWallpaperSeedSource implements WallpaperSeedSource {
  /// Creates the source.
  ///
  /// [wallpapers] and [extractor] are injectable for tests; the defaults talk to
  /// the session bus and decode with `dart:ui`.
  KdeWallpaperSeedSource({
    KdeWallpaperSource? wallpapers,
    this._extractor = const WallpaperPaletteExtractor(),
  }) : _wallpapers = wallpapers ?? KdeWallpaperSource();

  final KdeWallpaperSource _wallpapers;
  final WallpaperPaletteExtractor _extractor;

  @override
  Future<Either<Failure, DynamicSeeds>> seeds() async {
    // Step 1: Ask the shell which image it is showing.
    final located = await _wallpapers.fetchWallpaperPath();

    // Step 2: Read that image and reduce it to four seeds.
    return located.fold(
      (error) async => Left<Failure, DynamicSeeds>(Failure(error.message)),
      (path) => _extract(path),
    );
  }

  /// Reads [path] and extracts its seeds.
  Future<Either<Failure, DynamicSeeds>> _extract(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return Right(await _extractor.fromImageBytes(bytes));
    } catch (error) {
      return Left(Failure('Unable to extract seeds from $path: $error'));
    }
  }
}
