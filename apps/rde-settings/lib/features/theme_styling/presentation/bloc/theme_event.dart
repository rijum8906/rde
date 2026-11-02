import 'package:core/theme.dart';

/// Base class for events handled by the theme bloc.
abstract class ThemeEvent {
  const ThemeEvent();
}

/// Loads every slice of the theme state (also used to retry).
class ThemeInitEvent extends ThemeEvent {
  const ThemeInitEvent();
}

/// Asks the service to re-read manifests and settings, then refreshes the UI.
class ReloadThemeDatabaseEvent extends ThemeEvent {
  const ReloadThemeDatabaseEvent();
}

/// Internal event fired when the service changes one of its properties.
///
/// The notification carries only the slice that changed, so the bloc refreshes
/// exactly that slice instead of reloading the whole theme state.
class ThemeServiceChangedEvent extends ThemeEvent {
  const ThemeServiceChangedEvent({this.resolved, this.availableThemes});

  /// Payload the service published, `null` when the change was not a payload
  /// publication or the payload could not be read.
  final ResolvedTheme? resolved;

  /// Registry identifiers, `null` when the change did not report the registry.
  final List<String>? availableThemes;
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

/// Re-seeds every palette family of the built-in dynamic theme from one accent.
class SetDynamicAccentEvent extends ThemeEvent {
  const SetDynamicAccentEvent(this.accent);

  /// Accent color in any supported hexadecimal form.
  final String accent;
}

/// Extracts the four seeds from the wallpaper the desktop currently shows.
class ExtractWallpaperSeedsEvent extends ThemeEvent {
  const ExtractWallpaperSeedsEvent();
}
