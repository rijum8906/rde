import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';
import 'package:rde_launcher/features/app_search/domain/repositories/application_repository.dart';

/// # Launch Application
///
/// Launches one selected desktop application through the repository boundary.
class LaunchApplication {
  /// Creates the launch use case backed by [repository].
  const LaunchApplication(this.repository);

  /// Application launch provider.
  final ApplicationRepository repository;

  /// Starts [application] using its desktop entry.
  Future<void> call(DesktopApplication application) =>
      repository.launch(application);
}
