import 'package:flutter/material.dart';
import 'package:core/theme.dart';

class AppThemeState {
  final AppearanceMode appearanceMode;
  final Color accentColor;

  /// Desktop theme payload published by `org.rde.Theme`, when available.
  final ResolvedTheme? resolvedTheme;

  /// Theme built from [resolvedTheme], applied to the whole application.
  final ThemeData? theme;

  const AppThemeState({
    required this.appearanceMode,
    required this.accentColor,
    this.resolvedTheme,
    this.theme,
  });

  factory AppThemeState.initial() {
    return const AppThemeState(
      appearanceMode: AppearanceMode.light,
      accentColor: Color(0xFF6750A4),
    );
  }

  AppThemeState copyWith({
    AppearanceMode? appearanceMode,
    Color? accentColor,
    ResolvedTheme? resolvedTheme,
    ThemeData? theme,
    bool clearResolvedTheme = false,
  }) {
    return AppThemeState(
      appearanceMode: appearanceMode ?? this.appearanceMode,
      accentColor: accentColor ?? this.accentColor,
      resolvedTheme: clearResolvedTheme
          ? null
          : (resolvedTheme ?? this.resolvedTheme),
      theme: clearResolvedTheme ? null : (theme ?? this.theme),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemeState &&
          runtimeType == other.runtimeType &&
          appearanceMode == other.appearanceMode &&
          accentColor == other.accentColor &&
          resolvedTheme == other.resolvedTheme &&
          theme == other.theme;

  @override
  int get hashCode =>
      appearanceMode.hashCode ^
      accentColor.hashCode ^
      resolvedTheme.hashCode ^
      theme.hashCode;
}
