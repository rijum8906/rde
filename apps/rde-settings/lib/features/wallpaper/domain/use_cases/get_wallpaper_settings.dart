import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wallpaper/domain/entities/wallpaper_settings.dart';
import 'package:rde_settings/features/wallpaper/domain/repositories/wallpaper_repository.dart';

class GetWallpaperSettingsUseCase {
  final WallpaperRepository _repository;

  const GetWallpaperSettingsUseCase(this._repository);

  Future<Either<Failure, WallpaperSettings>> call() async {
    return _repository.getSettings();
  }
}
