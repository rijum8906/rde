import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';

/// Drives the Theme & Styling page from the `org.rde.Theme` service.
///
/// Every refresh touches only the slice that changed: a published payload
/// updates the colors without re-reading manifests, and the manifests are
/// re-read only when the registry itself changes.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc({required this._repository}) : super(ThemeState.initial()) {
    on<ThemeInitEvent>(_onInit);
    on<ReloadThemeDatabaseEvent>(_onReload);
    on<ThemeServiceChangedEvent>(_onServiceChanged);
    on<DismissThemeErrorEvent>(_onDismissError);
    on<SelectThemeEvent>(_onSelectTheme);
    on<SetAppearanceEvent>(_onSetAppearance);
    on<SetPreviewModeEvent>(_onSetPreviewMode);
    on<SetDynamicAccentEvent>(_onSetDynamicAccent);
    on<ExtractWallpaperSeedsEvent>(_onExtractWallpaperSeeds);

    // Listen for property changes. The payload and the registry are separate
    // streams, and both are debounced by 50ms so a burst of signals caused by a
    // single write is delivered once.
    _resolvedSubscription = _repository.watchResolvedTheme().listen(
      (resolved) => _scheduleChange(resolved: resolved),
      onError: (Object error) {
        debugPrint('org.rde.Theme payload signal failed: $error');
      },
    );
    _registrySubscription = _repository.watchThemeList().listen(
      (ids) => _scheduleChange(availableThemes: ids),
      onError: (Object error) {
        debugPrint('org.rde.Theme registry signal failed: $error');
      },
    );
  }

  final ThemeRepository _repository;
  StreamSubscription<ResolvedTheme>? _resolvedSubscription;
  StreamSubscription<List<String>>? _registrySubscription;
  Timer? _debounce;
  ResolvedTheme? _pendingResolved;
  List<String>? _pendingThemes;

  // ==========================================
  // INITIAL LOAD
  // ==========================================

  /// Reads every slice once, because the page renders all of them on open.
  Future<void> _onInit(ThemeInitEvent event, Emitter<ThemeState> emit) async {
    emit(state.copyWith(status: ThemeStatus.loading, clearError: true));

    // Step 1: Read the service properties (version, active theme, appearance).
    final snapshot = await _read(emit, _repository.loadSnapshot(), fatal: true);
    if (snapshot == null) return;

    // Step 2: Read the payload the desktop currently renders.
    final resolved = await _read(
      emit,
      _repository.getResolvedTheme(),
      fatal: true,
    );
    if (resolved == null) return;

    // Step 3: Read the manifests of the installed themes.
    final themes = await _read(emit, _repository.loadThemes(), fatal: true);
    if (themes == null) return;

    emit(
      state.copyWith(
        status: ThemeStatus.success,
        version: snapshot.version,
        currentTheme: resolved.themeId.isEmpty
            ? snapshot.activeThemeId
            : resolved.themeId,
        mode: snapshot.mode,
        resolved: resolved,
        themes: themes,
        previewMode: snapshot.mode,
        previewResolved: resolved,
        isBusy: false,
        clearError: true,
      ),
    );
  }

  // ==========================================
  // BACKGROUND UPDATES (The Fast Path)
  // ==========================================

  /// Applies the slice the service reported, without touching the others.
  Future<void> _onServiceChanged(
    ThemeServiceChangedEvent event,
    Emitter<ThemeState> emit,
  ) async {
    // Without a first load there is nothing to patch, so take the full path.
    if (!state.hasData) {
      return _onInit(const ThemeInitEvent(), emit);
    }

    // Step 1: The payload arrives with the notification. Only a notification
    // that could not deliver it costs one small `GetResolvedTheme` call.
    var resolved = event.resolved;
    if (resolved == null) {
      resolved = await _read(emit, _repository.getResolvedTheme());
      if (resolved == null) {
        // Ignore background errors to avoid flashing the UI.
        debugPrint('Failed to refresh theme colors: ${state.errorMessage}');
        return;
      }
    }
    _applyPayload(emit, resolved);

    // Step 2: Manifests are the expensive read, so they are refreshed only when
    // the registry list really differs from the one on screen.
    final registry = event.availableThemes;
    if (registry == null || _sameRegistry(registry)) return;

    final themes = await _read(emit, _repository.loadThemes());
    if (themes == null || isClosed) return;
    emit(state.copyWith(themes: themes));
  }

  // ==========================================
  // ACTIONS (Optimistic UI)
  // ==========================================

  Future<void> _onSetAppearance(
    SetAppearanceEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy || state.mode == event.mode) return;

    // Step 1: OPTIMISTIC UPDATE: switch the UI instantly. No waiting for D-Bus.
    emit(
      state.copyWith(isBusy: true, clearError: true, previewMode: event.mode),
    );

    final failure = _failureOf(await _repository.setMode(event.mode));
    if (failure != null) {
      // Step 2: ROLLBACK: revert the preview to the mode the desktop renders.
      emit(
        state.copyWith(
          isBusy: false,
          errorMessage: failure.message,
          previewMode: state.mode,
        ),
      );
      return;
    }

    // Step 3: COMMIT: the successful write is the new appearance. The palette
    // follows with the published payload, so no read is made here.
    emit(state.copyWith(isBusy: false, mode: event.mode));
  }

  Future<void> _onSelectTheme(
    SelectThemeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy) return;

    final previous = state.currentTheme;
    emit(state.copyWith(isBusy: true, clearError: true));
    final failure = _failureOf(await _repository.setTheme(event.theme));
    if (failure != null) {
      emit(
        state.copyWith(
          isBusy: false,
          currentTheme: previous,
          errorMessage: failure.message,
        ),
      );
      return;
    }

    // COMMIT: the successful write activates the theme immediately. The payload
    // arrives with the service notification, so the colors are not read here.
    emit(state.copyWith(isBusy: false, currentTheme: event.theme));
  }

  Future<void> _onSetDynamicAccent(
    SetDynamicAccentEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy) return;

    final seeds = seedsFromAccent(event.accent);
    emit(state.copyWith(isBusy: true, clearError: true));

    final failure = _failureOf(
      await _repository.updateDynamicTheme(
        primary: seeds.primary,
        secondary: seeds.secondary,
        tertiary: seeds.tertiary,
        error: seeds.error,
      ),
    );

    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
    } else {
      emit(state.copyWith(isBusy: false, dynamicSeeds: seeds));
    }
  }

  Future<void> _onExtractWallpaperSeeds(
    ExtractWallpaperSeedsEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isBusy) return;

    emit(state.copyWith(isBusy: true, clearError: true));

    final extracted = await _repository.seedsFromWallpaper();

    return extracted.fold(
      (failure) async =>
          emit(state.copyWith(isBusy: false, errorMessage: failure.message)),
      (seeds) async {
        final failure = _failureOf(
          await _repository.updateDynamicTheme(
            primary: seeds.primary,
            secondary: seeds.secondary,
            tertiary: seeds.tertiary,
            error: seeds.error,
          ),
        );
        if (failure != null) {
          emit(state.copyWith(isBusy: false, errorMessage: failure.message));
        } else {
          emit(state.copyWith(isBusy: false, dynamicSeeds: seeds));
        }
      },
    );
  }

  // ==========================================
  // PREVIEWS & MISC
  // ==========================================

  Future<void> _onSetPreviewMode(
    SetPreviewModeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.previewMode == event.mode) return;
    emit(state.copyWith(previewMode: event.mode));

    final rendered = state.resolved;
    if (rendered == null) return;

    // Previewing the appearance the desktop already renders needs no service
    // call: the payload on screen is the answer.
    if (state.previewMode == state.mode) {
      emit(state.copyWith(previewResolved: rendered));
      return;
    }

    final result = await _repository.preview(
      state.currentTheme,
      state.previewMode,
    );
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (resolved) => emit(state.copyWith(previewResolved: resolved)),
    );
  }

  Future<void> _onReload(
    ReloadThemeDatabaseEvent event,
    Emitter<ThemeState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, clearError: true));
    final failure = _failureOf(await _repository.reload());

    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    // The service may have picked up manifests and settings, so this is the one
    // path that re-reads every slice.
    final snapshot = await _read(emit, _repository.loadSnapshot());
    final resolved = await _read(emit, _repository.getResolvedTheme());
    final themes = await _read(emit, _repository.loadThemes());

    emit(
      state.copyWith(
        version: snapshot?.version,
        currentTheme: resolved?.themeId,
        mode: snapshot?.mode,
        resolved: resolved,
        themes: themes,
        isBusy: false,
      ),
    );
    if (resolved != null) {
      _applyPayload(emit, resolved);
    }
  }

  void _onDismissError(DismissThemeErrorEvent event, Emitter<ThemeState> emit) {
    emit(state.copyWith(clearError: true));
  }

  // ==========================================
  // HELPERS
  // ==========================================

  /// Applies a published payload: its theme id and variant are the active theme
  /// and the rendered appearance, so no property read is needed.
  void _applyPayload(Emitter<ThemeState> emit, ResolvedTheme resolved) {
    final mode = AppearanceMode.fromDbus(resolved.variant);
    emit(
      state.copyWith(
        status: ThemeStatus.success,
        currentTheme: resolved.themeId,
        mode: mode,
        resolved: resolved,
        previewResolved: state.previewMode == mode
            ? resolved
            : state.previewResolved,
      ),
    );
  }

  /// Awaits [request] and reports its failure, returning `null` on error.
  ///
  /// [fatal] marks a read the page cannot render without, which moves the state
  /// to [ThemeStatus.failure]; every other failure only sets the inline message.
  Future<T?> _read<T>(
    Emitter<ThemeState> emit,
    Future<Either<Failure, T>> request, {
    bool fatal = false,
  }) async {
    final result = await request;
    return result.fold((failure) {
      emit(
        state.copyWith(
          status: fatal ? ThemeStatus.failure : state.status,
          errorMessage: failure.message,
        ),
      );
      return null;
    }, (value) => value);
  }

  /// Whether [ids] matches the registry the page already shows.
  bool _sameRegistry(List<String> ids) {
    final installed = state.themes
        .map((theme) => theme.name)
        .where((name) => name != ThemeManifest.dynamicId)
        .toSet();
    return installed.length == ids.toSet().length && installed.containsAll(ids);
  }

  /// Coalesces a burst of service notifications into one change event.
  void _scheduleChange({
    ResolvedTheme? resolved,
    List<String>? availableThemes,
  }) {
    _pendingResolved = resolved ?? _pendingResolved;
    _pendingThemes = availableThemes ?? _pendingThemes;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 50), () {
      final pending = ThemeServiceChangedEvent(
        resolved: _pendingResolved,
        availableThemes: _pendingThemes,
      );
      _pendingResolved = null;
      _pendingThemes = null;
      add(pending);
    });
  }

  Failure? _failureOf(Either<Failure, void> result) {
    return result.fold((failure) => failure, (_) => null);
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _resolvedSubscription?.cancel();
    await _registrySubscription?.cancel();
    return super.close();
  }
}
