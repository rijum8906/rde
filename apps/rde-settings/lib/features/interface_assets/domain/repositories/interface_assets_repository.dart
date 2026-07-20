import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/interface_assets/domain/entities/interface_assets_settings.dart';

abstract interface class InterfaceAssetsRepository {
  Either<Failure, InterfaceAssetsSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(InterfaceAssetsSettings settings);
}
