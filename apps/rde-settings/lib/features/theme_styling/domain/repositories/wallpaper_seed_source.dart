import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';

/// Resolves the four dynamic seeds from the current desktop wallpaper.
///
/// The theme service never reads images, so the settings app owns this pipeline:
/// locate the wallpaper reported by the desktop shell, decode it, and reduce it
/// to four distinguishable dominant colors.
abstract interface class WallpaperSeedSource {
  /// Locates the current wallpaper and extracts its seed colors.
  ///
  /// # Returns
  /// The four seeds, already normalized to `#RRGGBB`.
  ///
  /// # Errors
  /// Returns a [Failure] when the desktop shell does not report a wallpaper or
  /// the image cannot be read or decoded.
  Future<Either<Failure, DynamicSeeds>> seeds();
}
