import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wm_bindings/domain/entities/wm_bindings_settings.dart';
import 'package:rde_settings/features/wm_bindings/domain/repositories/wm_bindings_repository.dart';

class GetWmBindingsSettingsUseCase {
  final WmBindingsRepository _repository;

  const GetWmBindingsSettingsUseCase(this._repository);

  Future<Either<Failure, WmBindingsSettings>> call() async {
    return _repository.getSettings();
  }
}
