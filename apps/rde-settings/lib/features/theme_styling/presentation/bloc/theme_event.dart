import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/domain/entities/dynamic_seeds.dart';

/// Base class for events handled by the theme bloc.
abstract class ThemeEvent {
  const ThemeEvent();
}

/// Loads the theme catalog for the first time (also used to retry).
class ThemeInitEvent extends ThemeEvent {
  const ThemeInitEvent();
}

/// Asks the service to re-read manifests and settings, then refreshes the UI.
class ReloadThemeDatabaseEvent extends ThemeEvent {
  const ReloadThemeDatabaseEvent();
}

/// Internal event fired when the service publishes a new theme state.
class ThemeServiceChangedEvent extends ThemeEvent {
  const ThemeServiceChangedEvent();
}

/// Dismisses the inline error banner without touching the service.
class DismissThemeErrorEvent extends ThemeEvent {
  const DismissThemeErrorEvent();
}

/// Activates an installed theme.
class SelectThemeEvent extends ThemeEvent {
  const SelectThemeEvent(this.theme);

  /// Identifier of the theme to activate.
  final String theme;
}

/// Switches the desktop light/dark appearance.
class SetAppearanceEvent extends ThemeEvent {
  const SetAppearanceEvent(this.mode);

  /// Appearance to persist for the whole desktop.
  final AppearanceMode mode;
}

/// Switches which appearance the live preview renders.
///
/// This only resolves a preview payload, not the desktop preference.
class SetPreviewModeEvent extends ThemeEvent {
  const SetPreviewModeEvent(this.mode);

  /// Appearance to render in the preview.
  final AppearanceMode mode;
}

/// Re-seeds one palette family of the built-in dynamic theme.
class SetDynamicSeedEvent extends ThemeEvent {
  const SetDynamicSeedEvent(this.role, this.seed);

  /// Family whose palette is regenerated.
  final DynamicSeedRole role;

  /// Seed color in any supported hexadecimal form.
  final String seed;
}

/// Extracts the four seeds from the wallpaper the desktop currently shows.
class ExtractWallpaperSeedsEvent extends ThemeEvent {
  const ExtractWallpaperSeedsEvent();
}
