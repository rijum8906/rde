import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/about_rde/domain/entities/about_rde_settings.dart';

abstract interface class AboutRdeRepository {
  Either<Failure, AboutRdeSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(AboutRdeSettings settings);
}
