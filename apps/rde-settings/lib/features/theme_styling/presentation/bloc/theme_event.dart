import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';

/// Base class for events handled by the theme bloc.
abstract class ThemeEvent {
  const ThemeEvent();
}

/// Loads the theme catalog for the first time (also used to retry).
class ThemeInitEvent extends ThemeEvent {
  const ThemeInitEvent();
}

/// Asks the service to re-read its database and then refreshes the UI.
class ReloadThemeDatabaseEvent extends ThemeEvent {
  const ReloadThemeDatabaseEvent();
}

/// Internal event fired when the service reports a property change.
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

  final String theme;
}

/// Creates a theme from a seed color and activates it.
class CreateThemeEvent extends ThemeEvent {
  const CreateThemeEvent({required this.name, required this.sourceColor});

  final String name;
  final String sourceColor;
}

/// Deletes an installed, non-active theme.
class DeleteThemeEvent extends ThemeEvent {
  const DeleteThemeEvent(this.theme);

  final String theme;
}

/// Re-seeds the active theme with a new source color.
class SetSourceColorEvent extends ThemeEvent {
  const SetSourceColorEvent(this.sourceColor);

  final String sourceColor;
}

/// Writes the global light/dark preference.
class SetColorSchemeEvent extends ThemeEvent {
  const SetColorSchemeEvent(this.scheme);

  final RdeColorScheme scheme;
}

/// Switches which palette the live preview renders.
///
/// This only changes the preview, not the desktop preference.
class SetPreviewSchemeEvent extends ThemeEvent {
  const SetPreviewSchemeEvent(this.scheme);

  final RdeColorScheme scheme;
}
