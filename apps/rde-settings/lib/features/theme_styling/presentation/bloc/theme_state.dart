import 'package:core/theme.dart';

/// Lifecycle of the theme page's data.
enum ThemeStatus { initial, loading, success, failure }

/// UI state of the Theme & Styling page.
///
/// The service state is kept as independent slices — the payload the desktop
/// renders, the manifests of the installed themes, and the contract version —
/// so refreshing one slice never forces the others to be read again.
class ThemeState {
  const ThemeState({
    required this.status,
    this.version = 0,
    this.currentTheme = '',
    this.mode = AppearanceMode.dark,
    this.resolved,
    this.themes = const [],
    this.previewMode = AppearanceMode.dark,
    this.previewResolved,
    this.dynamicSeeds = DynamicSeeds.fallback,
    this.isBusy = false,
    this.errorMessage,
  });

  /// State before the first load.
  factory ThemeState.initial() {
    return const ThemeState(status: ThemeStatus.initial);
  }

  /// Whether the page is loading for the first time, ready, or failed.
  final ThemeStatus status;

  /// Interface contract version reported by the service.
  final int version;

  /// Identifier of the active theme, empty until the first payload arrives.
  final String currentTheme;

  /// Appearance the desktop currently renders.
  final AppearanceMode mode;

  /// Payload the desktop currently renders, `null` until it is read.
  final ResolvedTheme? resolved;

  /// Manifests of every theme the picker offers, including the built-in
  /// dynamic theme. Re-read only when the registry changes.
  final List<ThemeManifest> themes;

  /// Appearance rendered by the live preview.
  final AppearanceMode previewMode;

  /// Payload the live preview renders, `null` until it is resolved.
  final ResolvedTheme? previewResolved;

  /// Seeds the dynamic palettes are generated from.
  ///
  /// The service exposes no seed properties, so this mirrors the last seeds this
  /// page wrote (or extracted) and starts at the service defaults.
  final DynamicSeeds dynamicSeeds;

  /// True while a service mutation or refresh is in flight.
  final bool isBusy;

  /// Last failure message shown inline above the controls.
  final String? errorMessage;

  /// Manifest of the active theme, or `null` while manifests are missing.
  ThemeManifest? get activeTheme {
    for (final theme in themes) {
      if (theme.name == currentTheme) {
        return theme;
      }
    }
    return null;
  }

  /// Whether the built-in dynamic theme is active.
  bool get isDynamicActive => currentTheme == ThemeManifest.dynamicId;

  /// Payload the live preview renders.
  ResolvedTheme? get previewTheme => previewResolved;

  /// Whether the service payload has been read at least once.
  ///
  /// The manifest list is deliberately not part of this check: a machine with no
  /// installed themes still renders its controls and says so in the picker.
  bool get hasData => resolved != null;

  ThemeState copyWith({
    ThemeStatus? status,
    int? version,
    String? currentTheme,
    AppearanceMode? mode,
    ResolvedTheme? resolved,
    List<ThemeManifest>? themes,
    AppearanceMode? previewMode,
    ResolvedTheme? previewResolved,
    DynamicSeeds? dynamicSeeds,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ThemeState(
      status: status ?? this.status,
      version: version ?? this.version,
      currentTheme: currentTheme ?? this.currentTheme,
      mode: mode ?? this.mode,
      resolved: resolved ?? this.resolved,
      themes: themes ?? this.themes,
      previewMode: previewMode ?? this.previewMode,
      previewResolved: previewResolved ?? this.previewResolved,
      dynamicSeeds: dynamicSeeds ?? this.dynamicSeeds,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
