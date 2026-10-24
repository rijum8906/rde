import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/create_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/delete_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/load_theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/reload_themes.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_source_color.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/watch_theme_changes.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';

/// Aggregates the `org.rde.Theme` operations for the Theme & Styling page.
///
/// Reads happen through [LoadThemeCatalogUseCase]; mutations go through the
/// matching use case and are always followed by a catalog reload, so the UI
/// reflects the service's authoritative state instead of optimistic guesses.
/// The bloc also subscribes to the service's property-change signal so theme
/// switches made by other RDE applications appear here immediately.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc({
    required this.loadThemeCatalog,
    required this.setTheme,
    required this.createTheme,
    required this.deleteTheme,
    required this.setSourceColor,
    required this.setColorScheme,
    required this.reloadThemes,
    required this.watchThemeChanges,
  }) : super(ThemeState.initial()) {
    on<ThemeInitEvent>(_onInit);
    on<ReloadThemeDatabaseEvent>(_onReload);
    on<ThemeServiceChangedEvent>(_onServiceChanged);
    on<DismissThemeErrorEvent>(_onDismissError);
    on<SelectThemeEvent>(_onSelectTheme);
    on<CreateThemeEvent>(_onCreateTheme);
    on<DeleteThemeEvent>(_onDeleteTheme);
    on<SetSourceColorEvent>(_onSetSourceColor);
    on<SetColorSchemeEvent>(_onSetColorScheme);
    on<SetPreviewSchemeEvent>(_onSetPreviewScheme);

    // Live sync is best effort: when the session bus cannot deliver the
    // signal, explicit actions and the refresh button still work.
    _subscription = watchThemeChanges().listen(
      (_) => add(const ThemeServiceChangedEvent()),
      onError: (Object error) {
        debugPrint('org.rde.Theme signal subscription failed: $error');
      },
    );
  }

  final LoadThemeCatalogUseCase loadThemeCatalog;
  final SetThemeUseCase setTheme;
  final CreateThemeUseCase createTheme;
  final DeleteThemeUseCase deleteTheme;
  final SetSourceColorUseCase setSourceColor;
  final SetColorSchemeUseCase setColorScheme;
  final ReloadThemesUseCase reloadThemes;
  final WatchThemeChangesUseCase watchThemeChanges;

  StreamSubscription<void>? _subscription;
  bool _isLoading = false;

  Future<void> _onInit(ThemeInitEvent event, Emitter<ThemeState> emit) {
    return _load(emit, showLoading: true);
  }

  Future<void> _onReload(
    ReloadThemeDatabaseEvent event,
    Emitter<ThemeState> emit,
  ) async {
    // Step 1: Ask the service to reconcile its database with the manifests on
    // disk, which also re-applies the active theme to the toolkit schemes.
    emit(state.copyWith(isBusy: true, clearError: true));
    final failure = _failureOf(await reloadThemes());
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    // Step 2: Re-read everything the page renders.
    await _load(emit);
  }

  Future<void> _onServiceChanged(
    ThemeServiceChangedEvent event,
    Emitter<ThemeState> emit,
  ) async {
    // A mutation in progress reloads explicitly; skipping avoids racing it.
    if (state.isBusy) {
      return;
    }
    await _load(emit);
  }

  void _onDismissError(DismissThemeErrorEvent event, Emitter<ThemeState> emit) {
    emit(state.copyWith(clearError: true));
  }

  Future<void> _onSelectTheme(
    SelectThemeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy) {
      return;
    }

    emit(state.copyWith(isBusy: true, clearError: true));
    final failure = _failureOf(await setTheme(event.theme));
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _load(emit);
  }

  Future<void> _onCreateTheme(
    CreateThemeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy) {
      return;
    }

    // Step 1: Install the theme from the requested seed color.
    emit(state.copyWith(isBusy: true, clearError: true));
    final createFailure = _failureOf(
      await createTheme(event.name, event.sourceColor),
    );
    if (createFailure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: createFailure.message));
      return;
    }

    // Step 2: Activate it so the newly created colors apply immediately.
    final activateFailure = _failureOf(await setTheme(event.name));

    // Step 3: Refresh the list regardless, because the theme now exists.
    await _load(emit);

    // Step 4: Surface an activation failure without hiding the new theme.
    if (activateFailure != null) {
      emit(state.copyWith(errorMessage: activateFailure.message));
    }
  }

  Future<void> _onDeleteTheme(
    DeleteThemeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy) {
      return;
    }

    // The service rejects deleting the active theme; fail fast with a clear
    // message instead of a round trip.
    if (event.theme == state.catalog?.currentTheme) {
      emit(
        state.copyWith(
          errorMessage:
              'The active theme cannot be deleted. '
              'Activate another theme first.',
        ),
      );
      return;
    }

    emit(state.copyWith(isBusy: true, clearError: true));
    final failure = _failureOf(await deleteTheme(event.theme));
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _load(emit);
  }

  Future<void> _onSetSourceColor(
    SetSourceColorEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy) {
      return;
    }

    emit(state.copyWith(isBusy: true, clearError: true));
    final failure = _failureOf(await setSourceColor(event.sourceColor));
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _load(emit);
  }

  Future<void> _onSetColorScheme(
    SetColorSchemeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy || state.colorScheme == event.scheme) {
      return;
    }

    emit(
      state.copyWith(
        isBusy: true,
        clearError: true,
        previewScheme: event.scheme,
      ),
    );
    final failure = _failureOf(await setColorScheme(event.scheme));
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _load(emit);
  }

  void _onSetPreviewScheme(
    SetPreviewSchemeEvent event,
    Emitter<ThemeState> emit,
  ) {
    emit(state.copyWith(previewScheme: event.scheme));
  }

  /// Loads the catalog and publishes it as the new state.
  ///
  /// Concurrent loads are dropped; the last emitted state always reflects a
  /// complete read of the service.
  Future<void> _load(
    Emitter<ThemeState> emit, {
    bool showLoading = false,
  }) async {
    if (_isLoading) {
      return;
    }
    _isLoading = true;

    try {
      // Step 1: Show a spinner only for the very first load, otherwise keep
      // the current content visible while refreshing.
      if (showLoading && !state.hasCatalog) {
        emit(state.copyWith(status: ThemeStatus.loading, clearError: true));
      } else {
        emit(state.copyWith(isBusy: true, clearError: true));
      }

      // Step 2: Read the theme catalog.
      Failure? failure;
      ThemeCatalog? catalog;
      final result = await loadThemeCatalog();
      result.fold((value) => failure = value, (value) => catalog = value);

      if (failure != null || catalog == null) {
        emit(
          state.copyWith(
            status: state.hasCatalog
                ? ThemeStatus.success
                : ThemeStatus.failure,
            isBusy: false,
            errorMessage: failure?.message,
          ),
        );
        return;
      }

      // Step 3: Publish the new catalog. The preview follows the desktop
      // scheme on the first load and keeps the user's choice afterwards.
      final loaded = catalog!;
      emit(
        state.copyWith(
          status: ThemeStatus.success,
          catalog: loaded,
          previewScheme: state.hasCatalog
              ? state.previewScheme
              : loaded.colorScheme,
          isBusy: false,
          clearError: true,
        ),
      );
    } finally {
      _isLoading = false;
    }
  }

  /// Extracts the failure of a void result, or `null` on success.
  Failure? _failureOf(Either<Failure, void> result) {
    return result.fold((failure) => failure, (_) => null);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
