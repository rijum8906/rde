import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/interface_assets/domain/entities/interface_assets_settings.dart';
import 'package:rde_settings/features/interface_assets/domain/repositories/interface_assets_repository.dart';

class SaveInterfaceAssetsSettingsUseCase {
  final InterfaceAssetsRepository _repository;

  const SaveInterfaceAssetsSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(InterfaceAssetsSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
