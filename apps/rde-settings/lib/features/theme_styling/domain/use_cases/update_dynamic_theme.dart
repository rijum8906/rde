import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Updates the seed colors of the built-in dynamic theme.
class UpdateDynamicThemeUseCase {
  const UpdateDynamicThemeUseCase(this._repository);

  final ThemeRepository _repository;

  /// Persists the requested seeds and republishes the dynamic theme when it is
  /// active.
  ///
  /// Passing an empty string for a role keeps its stored seed, so a caller that
  /// only changes the accent can leave the other families untouched.
  Future<Either<Failure, void>> call({
    String primary = '',
    String secondary = '',
    String tertiary = '',
    String error = '',
  }) {
    return _repository.updateDynamicTheme(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      error: error,
    );
  }
}
