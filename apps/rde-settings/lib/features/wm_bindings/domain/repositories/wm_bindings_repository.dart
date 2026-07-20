import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wm_bindings/domain/entities/wm_bindings_settings.dart';

abstract interface class WmBindingsRepository {
  Either<Failure, WmBindingsSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(WmBindingsSettings settings);
}
