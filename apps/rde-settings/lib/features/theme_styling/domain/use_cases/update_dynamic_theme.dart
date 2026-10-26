import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/core/theme/domain/entities/seed_source.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Updates the inputs of the built-in dynamic theme.
class UpdateDynamicThemeUseCase {
  const UpdateDynamicThemeUseCase(this._repository);

  final ThemeRepository _repository;

  /// Persists the requested inputs and republishes the dynamic theme when it is
  /// active.
  Future<Either<Failure, void>> call({
    required SeedSource seedSource,
    String seed = '',
    String wallpaper = '',
  }) {
    return _repository.updateDynamicTheme(
      seedSource: seedSource,
      seed: seed,
      wallpaper: wallpaper,
    );
  }
}
