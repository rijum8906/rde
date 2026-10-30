import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/find_applications.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/launch_application.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/load_applications.dart';
import 'package:rde_launcher/features/app_search/presentation/bloc/app_search_state.dart';

/// # Application Search Bloc
///
/// Owns launcher discovery, filtering, keyboard selection, and launch actions.
class AppSearchBloc extends Cubit<AppSearchState> {
  /// Creates the search controller and loads the desktop application menu.
  AppSearchBloc({
    required this.loadApplications,
    required this.findApplications,
    required this.launchApplication,
  }) : super(const AppSearchState()) {
    load();
  }

  /// Loads installed desktop applications.
  final LoadApplications loadApplications;

  /// Filters applications against the current query.
  final FindApplications findApplications;

  /// Launches a selected application.
  final LaunchApplication launchApplication;

  /// Discovers installed applications.
  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final applications = await loadApplications();
      emit(
        state.copyWith(
          applications: applications,
          results: _filter(applications, state.query, state.category),
          selectedIndex: 0,
          isLoading: false,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Unable to load applications: $error',
        ),
      );
    }
  }

  /// Filters the loaded applications by [query].
  void search(String query) {
    emit(
      state.copyWith(
        query: query,
        results: _filter(state.applications, query, state.category),
        selectedIndex: 0,
        clearError: true,
      ),
    );
  }

  /// Restricts the results to [category], or every category for an empty value.
  void filterCategory(String category) {
    emit(
      state.copyWith(
        category: category,
        results: _filter(state.applications, state.query, category),
        selectedIndex: 0,
        clearError: true,
      ),
    );
  }

  /// Clears the search text and category filter at once.
  void clearFilters() {
    emit(
      state.copyWith(
        query: '',
        category: '',
        results: _filter(state.applications, '', ''),
        selectedIndex: 0,
        clearError: true,
      ),
    );
  }

  /// Applies the search query and category filter in a single pass.
  List<DesktopApplication> _filter(
    List<DesktopApplication> applications,
    String query,
    String category,
  ) {
    final matches = findApplications(applications, query);
    if (category.isEmpty) {
      return matches;
    }
    return matches
        .where((application) => application.categoryLabel == category)
        .toList(growable: false);
  }

  /// Moves the highlighted application by [delta], wrapping at each end.
  void moveSelection(int delta) {
    if (state.results.isEmpty) {
      return;
    }
    final next = (state.selectedIndex + delta) % state.results.length;
    emit(
      state.copyWith(
        selectedIndex: next < 0 ? next + state.results.length : next,
      ),
    );
  }

  /// Highlights a result by pointer index.
  void select(int index) {
    if (index < 0 || index >= state.results.length) {
      return;
    }
    emit(state.copyWith(selectedIndex: index));
  }

  /// Launches [application] or the current selection and exposes failures.
  Future<void> launch([DesktopApplication? application]) async {
    final target = application ?? state.selectedApplication;
    if (target == null || state.isLaunching) {
      return;
    }

    emit(state.copyWith(isLaunching: true, clearError: true));
    try {
      await launchApplication(target);
      emit(state.copyWith(isLaunching: false));
    } catch (error) {
      emit(
        state.copyWith(
          isLaunching: false,
          error: 'Unable to launch ${target.name}: $error',
        ),
      );
    }
  }
}
