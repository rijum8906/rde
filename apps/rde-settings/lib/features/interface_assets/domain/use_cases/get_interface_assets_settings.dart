import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/interface_assets/domain/entities/interface_assets_settings.dart';
import 'package:rde_settings/features/interface_assets/domain/repositories/interface_assets_repository.dart';

class GetInterfaceAssetsSettingsUseCase {
  final InterfaceAssetsRepository _repository;

  const GetInterfaceAssetsSettingsUseCase(this._repository);

  Future<Either<Failure, InterfaceAssetsSettings>> call() async {
    return _repository.getSettings();
  }
}
