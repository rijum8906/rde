import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wallpaper/domain/entities/wallpaper_settings.dart';
import 'package:rde_settings/features/wallpaper/domain/repositories/wallpaper_repository.dart';

class SaveWallpaperSettingsUseCase {
  final WallpaperRepository _repository;

  const SaveWallpaperSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(WallpaperSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
