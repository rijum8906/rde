import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/pointer/domain/entities/pointer_settings.dart';

abstract interface class PointerRepository {
  Either<Failure, PointerSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(PointerSettings settings);
}
