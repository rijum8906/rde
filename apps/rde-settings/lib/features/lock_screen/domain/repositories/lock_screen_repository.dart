import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/lock_screen/domain/entities/lock_screen_settings.dart';

abstract interface class LockScreenRepository {
  Either<Failure, LockScreenSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(LockScreenSettings settings);
}
