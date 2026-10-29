import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';

/// # Application Repository
///
/// Provides installed applications and launches a selected application without
/// exposing Linux desktop integration details to presentation code.
abstract interface class ApplicationRepository {
  /// Loads visible installed applications from the desktop application menu.
  Future<List<DesktopApplication>> loadApplications();

  /// Launches [application] using its desktop entry ID.
  Future<void> launch(DesktopApplication application);
}
