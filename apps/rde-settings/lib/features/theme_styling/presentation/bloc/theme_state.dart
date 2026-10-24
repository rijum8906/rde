import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_palette.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_theme_info.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';

/// Lifecycle of the theme page's data.
enum ThemeStatus { initial, loading, success, failure }

/// UI state of the Theme & Styling page.
class ThemeState {
  const ThemeState({
    required this.status,
    this.catalog,
    this.previewScheme = RdeColorScheme.dark,
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

  /// Scheme rendered by the live preview.
  final RdeColorScheme previewScheme;

  /// True while a service mutation or catalog refresh is in flight.
  final bool isBusy;

  /// Last failure message shown inline above the controls.
  final String? errorMessage;

  /// Installed themes, empty until the catalog is loaded.
  List<RdeThemeInfo> get themes => catalog?.themes ?? const [];

  /// Metadata of the active theme.
  RdeThemeInfo? get activeTheme => catalog?.activeTheme;

  /// Global scheme of the desktop.
  RdeColorScheme get colorScheme => catalog?.colorScheme ?? RdeColorScheme.dark;

  /// Palette the live preview renders.
  RdePalette? get previewPalette => catalog?.paletteFor(previewScheme);

  /// Whether the catalog has been loaded at least once.
  bool get hasCatalog => catalog != null;

  ThemeState copyWith({
    ThemeStatus? status,
    ThemeCatalog? catalog,
    RdeColorScheme? previewScheme,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ThemeState(
      status: status ?? this.status,
      catalog: catalog ?? this.catalog,
      previewScheme: previewScheme ?? this.previewScheme,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
