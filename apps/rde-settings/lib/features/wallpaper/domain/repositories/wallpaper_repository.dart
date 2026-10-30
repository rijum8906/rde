import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/wallpaper/domain/entities/wallpaper_settings.dart';

abstract interface class WallpaperRepository {
  Either<Failure, WallpaperSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(WallpaperSettings settings);
}
