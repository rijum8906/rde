import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_styling_settings.dart';

abstract interface class ThemeStylingRepository {
  Either<Failure, ThemeStylingSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(ThemeStylingSettings settings);
}
