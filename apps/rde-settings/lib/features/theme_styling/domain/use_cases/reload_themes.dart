import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Asks the service to re-read the theme database from disk.
class ReloadThemesUseCase {
  const ReloadThemesUseCase(this._repository);

  final ThemeRepository _repository;

  Future<Either<Failure, void>> call() => _repository.reload();
}
