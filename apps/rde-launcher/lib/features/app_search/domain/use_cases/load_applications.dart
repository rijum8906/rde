import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';
import 'package:rde_launcher/features/app_search/domain/repositories/application_repository.dart';

/// # Load Applications
///
/// Loads the installed application menu through the repository boundary.
class LoadApplications {
  /// Creates the use case backed by [repository].
  const LoadApplications(this.repository);

  /// Application menu data source.
  final ApplicationRepository repository;

  /// Returns available applications.
  Future<List<DesktopApplication>> call() => repository.loadApplications();
}
