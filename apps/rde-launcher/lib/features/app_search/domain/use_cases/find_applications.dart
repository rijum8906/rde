import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';

/// # Find Applications
///
/// Filters installed applications by name, description, ID, or category.
class FindApplications {
  /// Creates the application search use case.
  const FindApplications();

  /// Returns matching applications in alphabetical order.
  List<DesktopApplication> call(
    Iterable<DesktopApplication> applications,
    String query,
  ) {
    final matches = applications
        .where((application) => application.matches(query))
        .toList();
    matches.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return matches;
  }
}
