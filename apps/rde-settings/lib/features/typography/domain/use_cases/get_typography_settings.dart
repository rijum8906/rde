import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/typography/domain/entities/typography_settings.dart';
import 'package:rde_settings/features/typography/domain/repositories/typography_repository.dart';

class GetTypographySettingsUseCase {
  final TypographyRepository _repository;

  const GetTypographySettingsUseCase(this._repository);

  Future<Either<Failure, TypographySettings>> call() async {
    return _repository.getSettings();
  }
}
