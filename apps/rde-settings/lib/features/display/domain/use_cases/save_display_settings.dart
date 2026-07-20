import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/display/domain/entities/display_settings.dart';
import 'package:rde_settings/features/display/domain/repositories/display_repository.dart';

class SaveDisplaySettingsUseCase {
  final DisplayRepository _repository;

  const SaveDisplaySettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(DisplaySettings settings) async {
    return _repository.saveSettings(settings);
  }
}
