import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Extracts the dynamic seeds from the wallpaper the desktop displays.
///
/// The settings app owns wallpaper decoding; the theme service only accepts the
/// resulting colors.
class ExtractWallpaperSeedsUseCase {
  const ExtractWallpaperSeedsUseCase(this._repository);

  final ThemeRepository _repository;

  Future<Either<Failure, DynamicSeeds>> call() =>
      _repository.seedsFromWallpaper();
}
