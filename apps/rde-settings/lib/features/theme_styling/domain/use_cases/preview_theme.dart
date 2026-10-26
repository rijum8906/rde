import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/domain/entities/resolved_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Resolves a theme for one appearance without committing it.
class PreviewThemeUseCase {
  const PreviewThemeUseCase(this._repository);

  final ThemeRepository _repository;

  Future<Either<Failure, ResolvedTheme>> call(
    String theme,
    AppearanceMode mode, [
    ContrastLevel contrast = ContrastLevel.normal,
  ]) {
    return _repository.preview(theme, mode, contrast);
  }
}
