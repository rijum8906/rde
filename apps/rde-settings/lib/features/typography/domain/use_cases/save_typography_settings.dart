import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/typography/domain/entities/typography_settings.dart';
import 'package:rde_settings/features/typography/domain/repositories/typography_repository.dart';

class SaveTypographySettingsUseCase {
  final TypographyRepository _repository;

  const SaveTypographySettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(TypographySettings settings) async {
    return _repository.saveSettings(settings);
  }
}
