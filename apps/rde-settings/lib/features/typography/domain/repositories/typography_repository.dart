import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/typography/domain/entities/typography_settings.dart';

abstract interface class TypographyRepository {
  Either<Failure, TypographySettings> getSettings();
  Future<Either<Failure, void>> saveSettings(TypographySettings settings);
}
