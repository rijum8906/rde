import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';

/// # Application Search State
///
/// Describes the launcher search results, active selection, and transient
/// discovery or launch feedback.
class AppSearchState {
  /// Creates a search state snapshot.
  const AppSearchState({
    this.applications = const [],
    this.results = const [],
    this.query = '',
    this.category = '',
    this.selectedIndex = 0,
    this.isLoading = true,
    this.isLaunching = false,
    this.error,
  });

  /// Complete list of installed applications loaded at startup.
  final List<DesktopApplication> applications;

  /// Applications matching [query].
  final List<DesktopApplication> results;

  /// Current search text.
  final String query;

  /// Active category filter, or an empty string for every category.
  final String category;

  /// Categories present in the loaded application menu, most common first.
  List<String> get availableCategories {
    final counts = <String, int>{};
    for (final application in applications) {
      final label = application.categoryLabel;
      if (label.isNotEmpty) {
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }

    // Step 1: Surface the categories users are most likely to browse first.
    final labels = counts.keys.toList()
      ..sort((left, right) {
        final byCount = counts[right]!.compareTo(counts[left]!);
        return byCount != 0 ? byCount : left.compareTo(right);
      });

    // Step 2: Keep the filter row compact; search still reaches the rest.
    return labels.take(6).toList(growable: false);
  }

  /// Index selected by keyboard or pointer.
  final int selectedIndex;

  /// Whether initial application discovery is running.
  final bool isLoading;

  /// Whether the selected application is being launched.
  final bool isLaunching;

  /// Error shown when discovery or launch fails.
  final String? error;

  /// Currently selected matching application, if any.
  DesktopApplication? get selectedApplication => results.isEmpty
      ? null
      : results[selectedIndex.clamp(0, results.length - 1)];

  /// Creates an updated snapshot while preserving unspecified values.
  AppSearchState copyWith({
    List<DesktopApplication>? applications,
    List<DesktopApplication>? results,
    String? query,
    String? category,
    int? selectedIndex,
    bool? isLoading,
    bool? isLaunching,
    String? error,
    bool clearError = false,
  }) {
    return AppSearchState(
      applications: applications ?? this.applications,
      results: results ?? this.results,
      query: query ?? this.query,
      category: category ?? this.category,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isLoading: isLoading ?? this.isLoading,
      isLaunching: isLaunching ?? this.isLaunching,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
