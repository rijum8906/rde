import 'package:flutter/material.dart';
import 'package:core/theme.dart';

abstract class AppThemeEvent {
  const AppThemeEvent();
}

/// Overrides the appearance locally, without asking the theme service.
///
/// The Theme & Styling page switches the desktop appearance through
/// `org.rde.Theme`; this event remains for screens that only restyle the
/// settings window itself.
class ChangeThemeModeEvent extends AppThemeEvent {
  final AppearanceMode appearanceMode;
  const ChangeThemeModeEvent(this.appearanceMode);
}

/// Replaces the theme with a locally picked accent color.
///
/// A local accent has no service payload behind it, so the resolved theme is
/// dropped and the seed color builds both schemes again.
class ChangeAccentColorEvent extends AppThemeEvent {
  final Color accentColor;
  const ChangeAccentColorEvent(this.accentColor);
}

/// Applies the theme published by `org.rde.Theme`.
///
/// [resolved] is the payload returned by `GetResolvedTheme` or decoded from the
/// `ThemeChanged` signal, and [mode] is the appearance it was resolved for.
/// Together they rebuild the whole app theme: colors, typography, shape, and
/// motion.
class ApplyResolvedThemeEvent extends AppThemeEvent {
  const ApplyResolvedThemeEvent({required this.resolved, required this.mode});

  /// Desktop theme payload to render.
  final ResolvedTheme resolved;

  /// Appearance the payload was resolved for.
  final AppearanceMode mode;
}
