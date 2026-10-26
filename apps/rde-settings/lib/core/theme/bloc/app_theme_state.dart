import 'package:flutter/material.dart';
import 'package:rde_settings/core/theme/domain/entities/resolved_theme.dart';

class AppThemeState {
  final ThemeMode themeMode;
  final Color accentColor;

  /// Desktop theme payload published by `org.rde.Theme`, when available.
  final ResolvedTheme? resolvedTheme;

  /// Theme built from [resolvedTheme], applied to the whole application.
  final ThemeData? theme;

  const AppThemeState({
    required this.themeMode,
    required this.accentColor,
    this.resolvedTheme,
    this.theme,
  });

  factory AppThemeState.initial() {
    return const AppThemeState(
      themeMode: ThemeMode.system,
      accentColor: Color(0xFF6750A4),
    );
  }

  AppThemeState copyWith({
    ThemeMode? themeMode,
    Color? accentColor,
    ResolvedTheme? resolvedTheme,
    ThemeData? theme,
    bool clearResolvedTheme = false,
  }) {
    return AppThemeState(
      themeMode: themeMode ?? this.themeMode,
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
          themeMode == other.themeMode &&
          accentColor == other.accentColor &&
          resolvedTheme == other.resolvedTheme &&
          theme == other.theme;

  @override
  int get hashCode =>
      themeMode.hashCode ^
      accentColor.hashCode ^
      resolvedTheme.hashCode ^
      theme.hashCode;
}
