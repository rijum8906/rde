import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/domain/entities/resolved_theme.dart';
import 'package:rde_settings/core/theme/domain/entities/theme_manifest.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';

/// Lifecycle of the theme page's data.
enum ThemeStatus { initial, loading, success, failure }

/// UI state of the Theme & Styling page.
class ThemeState {
  const ThemeState({
    required this.status,
    this.catalog,
    this.previewMode = AppearanceMode.dark,
    this.previewResolved,
    this.isBusy = false,
    this.errorMessage,
  });

  factory ThemeState.initial() {
    return const ThemeState(status: ThemeStatus.initial);
  }

  /// Whether the page is loading for the first time, ready, or failed.
  final ThemeStatus status;

  /// Latest service state, `null` until the first successful load.
  final ThemeCatalog? catalog;

  /// Appearance rendered by the live preview.
  final AppearanceMode previewMode;

  /// Payload the live preview renders, `null` until it is resolved.
  final ResolvedTheme? previewResolved;

  /// True while a service mutation or catalog refresh is in flight.
  final bool isBusy;

  /// Last failure message shown inline above the controls.
  final String? errorMessage;

  /// Installed themes, empty until the catalog is loaded.
  List<ThemeManifest> get themes => catalog?.themes ?? const [];

  /// Manifest of the active theme.
  ThemeManifest? get activeTheme => catalog?.activeTheme;

  /// Appearance the desktop currently renders.
  AppearanceMode get mode => catalog?.mode ?? AppearanceMode.dark;

  /// Payload the live preview renders.
  ResolvedTheme? get previewTheme => previewResolved;

  /// Whether the catalog has been loaded at least once.
  bool get hasCatalog => catalog != null;

  ThemeState copyWith({
    ThemeStatus? status,
    ThemeCatalog? catalog,
    AppearanceMode? previewMode,
    ResolvedTheme? previewResolved,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ThemeState(
      status: status ?? this.status,
      catalog: catalog ?? this.catalog,
      previewMode: previewMode ?? this.previewMode,
      previewResolved: previewResolved ?? this.previewResolved,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
