import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/pointer/domain/entities/pointer_settings.dart';
import 'package:rde_settings/features/pointer/domain/repositories/pointer_repository.dart';

class GetPointerSettingsUseCase {
  final PointerRepository _repository;

  const GetPointerSettingsUseCase(this._repository);

  Future<Either<Failure, PointerSettings>> call() async {
    return _repository.getSettings();
  }
}
