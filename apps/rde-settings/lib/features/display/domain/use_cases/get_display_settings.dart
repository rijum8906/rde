import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/display/domain/entities/display_settings.dart';
import 'package:rde_settings/features/display/domain/repositories/display_repository.dart';

class GetDisplaySettingsUseCase {
  final DisplayRepository _repository;

  const GetDisplaySettingsUseCase(this._repository);

  Future<Either<Failure, DisplaySettings>> call() async {
    return _repository.getSettings();
  }
}
