import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/core/utils/accent_seeds.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/extract_wallpaper_seeds.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/load_theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/preview_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/reload_themes.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_mode.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/update_dynamic_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/watch_theme_changes.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';

/// Aggregates the `org.rde.Theme` operations for the Theme & Styling page.
///
/// Reads happen through [LoadThemeCatalogUseCase]; mutations go through the
/// matching use case and are always followed by a catalog reload, so the UI
/// reflects the service's authoritative state instead of optimistic guesses.
/// The bloc also subscribes to the service's `ThemeChanged` and
/// `ThemeListChanged` signals so theme switches made by other RDE applications
/// appear here immediately.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc({
    required this.loadThemeCatalog,
    required this.previewTheme,
    required this.setTheme,
    required this.setMode,
    required this.updateDynamicTheme,
    required this.extractWallpaperSeeds,
    required this.reloadThemes,
    required this.watchThemeChanges,
  }) : super(ThemeState.initial()) {
    on<ThemeInitEvent>(_onInit);
    on<ReloadThemeDatabaseEvent>(_onReload);
    on<ThemeServiceChangedEvent>(_onServiceChanged);
    on<DismissThemeErrorEvent>(_onDismissError);
    on<SelectThemeEvent>(_onSelectTheme);
    on<SetAppearanceEvent>(_onSetAppearance);
    on<SetPreviewModeEvent>(_onSetPreviewMode);
    on<SetDynamicAccentEvent>(_onSetDynamicAccent);
    on<ExtractWallpaperSeedsEvent>(_onExtractWallpaperSeeds);

    // Live sync is best effort: when the session bus cannot deliver the
    // signals, explicit actions and the refresh button still work.
    _subscription = watchThemeChanges().listen(
      (_) => add(const ThemeServiceChangedEvent()),
      onError: (Object error) {
        debugPrint('org.rde.Theme signal subscription failed: $error');
      },
    );
  }

  final LoadThemeCatalogUseCase loadThemeCatalog;
  final PreviewThemeUseCase previewTheme;
  final SetThemeUseCase setTheme;
  final SetModeUseCase setMode;
  final UpdateDynamicThemeUseCase updateDynamicTheme;
  final ExtractWallpaperSeedsUseCase extractWallpaperSeeds;
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
    // Step 1: Ask the service to reconcile manifests, variant files, and
    // settings with what is durable on disk.
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

  Future<void> _onSetAppearance(
    SetAppearanceEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy || state.mode == event.mode) {
      return;
    }

    emit(
      state.copyWith(isBusy: true, clearError: true, previewMode: event.mode),
    );
    final failure = _failureOf(await setMode(event.mode));
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _load(emit);
  }

  Future<void> _onSetPreviewMode(
    SetPreviewModeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.previewMode == event.mode) {
      return;
    }

    emit(state.copyWith(previewMode: event.mode));
    await _loadPreview(emit);
  }

  Future<void> _onSetDynamicAccent(
    SetDynamicAccentEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy) {
      return;
    }

    // Step 1: Derive every family from the picked accent. The helper also
    // normalizes the hex form and falls back when the value is malformed.
    final seeds = seedsFromAccent(event.accent);

    emit(state.copyWith(isBusy: true, clearError: true));

    // Step 2: Send all four seeds; the service regenerates each palette.
    final failure = _failureOf(
      await updateDynamicTheme(
        primary: seeds.primary,
        secondary: seeds.secondary,
        tertiary: seeds.tertiary,
        error: seeds.error,
      ),
    );
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    // Step 3: Mirror the derived seeds and refresh the catalog.
    emit(state.copyWith(dynamicSeeds: seeds));
    await _load(emit);
  }

  Future<void> _onExtractWallpaperSeeds(
    ExtractWallpaperSeedsEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy) {
      return;
    }

    emit(state.copyWith(isBusy: true, clearError: true));

    // Step 1: The app owns wallpaper decoding; ask it for the four seeds.
    final extracted = await extractWallpaperSeeds();

    // Step 2: Hand the seeds to the service, which regenerates every family.
    return extracted.fold(
      (failure) async =>
          emit(state.copyWith(isBusy: false, errorMessage: failure.message)),
      (seeds) async {
        final failure = _failureOf(
          await updateDynamicTheme(
            primary: seeds.primary,
            secondary: seeds.secondary,
            tertiary: seeds.tertiary,
            error: seeds.error,
          ),
        );
        if (failure != null) {
          emit(state.copyWith(isBusy: false, errorMessage: failure.message));
          return;
        }

        // Step 3: Mirror the extracted seeds and refresh the catalog.
        emit(state.copyWith(dynamicSeeds: seeds));
        await _load(emit);
      },
    );
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
      // appearance on the first load and keeps the user's choice afterwards.
      final loaded = catalog!;
      final firstLoad = !state.hasCatalog;
      final previewMode = firstLoad ? loaded.mode : state.previewMode;
      emit(
        state.copyWith(
          status: ThemeStatus.success,
          catalog: loaded,
          previewMode: previewMode,
          previewResolved: previewMode == loaded.mode
              ? loaded.resolved
              : state.previewResolved,
          isBusy: false,
          clearError: true,
        ),
      );

      // Step 4: Re-resolve the preview when it shows the other appearance.
      if (previewMode != loaded.mode) {
        await _loadPreview(emit);
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Resolves the payload the live preview renders.
  ///
  /// The active appearance is served from the loaded catalog; the other one is
  /// computed by the service through `Preview` without committing it.
  Future<void> _loadPreview(Emitter<ThemeState> emit) async {
    final catalog = state.catalog;
    if (catalog == null) {
      return;
    }

    // Step 1: Reuse the published payload when the preview shows it.
    if (state.previewMode == catalog.mode) {
      emit(state.copyWith(previewResolved: catalog.resolved));
      return;
    }

    // Step 2: Ask the service for a preview of the other appearance.
    final result = await previewTheme(catalog.currentTheme, state.previewMode);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (resolved) => emit(state.copyWith(previewResolved: resolved)),
    );
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
