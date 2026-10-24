import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Watches the service for theme changes made outside this application.
class WatchThemeChangesUseCase {
  const WatchThemeChangesUseCase(this._repository);

  final ThemeRepository _repository;

  Stream<void> call() => _repository.watchThemeChanges();
}
