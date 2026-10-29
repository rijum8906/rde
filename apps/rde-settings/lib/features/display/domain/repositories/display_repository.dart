import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/display/domain/entities/display_settings.dart';

abstract interface class DisplayRepository {
  Either<Failure, DisplaySettings> getSettings();
  Future<Either<Failure, void>> saveSettings(DisplaySettings settings);
}
