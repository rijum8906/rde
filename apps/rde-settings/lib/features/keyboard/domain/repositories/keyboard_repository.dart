import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/keyboard/domain/entities/keyboard_settings.dart';

abstract interface class KeyboardRepository {
  Either<Failure, KeyboardSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(KeyboardSettings settings);
}
