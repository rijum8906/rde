import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/about_rde/domain/entities/about_rde_settings.dart';
import 'package:rde_settings/features/about_rde/domain/repositories/about_rde_repository.dart';

class GetAboutRdeSettingsUseCase {
  final AboutRdeRepository _repository;

  const GetAboutRdeSettingsUseCase(this._repository);

  Future<Either<Failure, AboutRdeSettings>> call() async {
    return _repository.getSettings();
  }
}
