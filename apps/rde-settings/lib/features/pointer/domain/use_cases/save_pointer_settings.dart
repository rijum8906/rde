import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/pointer/domain/entities/pointer_settings.dart';
import 'package:rde_settings/features/pointer/domain/repositories/pointer_repository.dart';

class SavePointerSettingsUseCase {
  final PointerRepository _repository;

  const SavePointerSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(PointerSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
