import 'package:flutter/material.dart';

abstract class AppThemeEvent {
  const AppThemeEvent();
}

class ChangeThemeModeEvent extends AppThemeEvent {
  final ThemeMode themeMode;
  const ChangeThemeModeEvent(this.themeMode);
}

class ChangeAccentColorEvent extends AppThemeEvent {
  final Color accentColor;
  const ChangeAccentColorEvent(this.accentColor);
}
