import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/about_rde/domain/entities/about_rde_settings.dart';
import 'package:rde_settings/features/about_rde/domain/repositories/about_rde_repository.dart';

class SaveAboutRdeSettingsUseCase {
  final AboutRdeRepository _repository;

  const SaveAboutRdeSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(AboutRdeSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
