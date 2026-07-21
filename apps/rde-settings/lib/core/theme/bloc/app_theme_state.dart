import 'package:flutter/material.dart';

class AppThemeState {
  final ThemeMode themeMode;
  final Color accentColor;

  const AppThemeState({required this.themeMode, required this.accentColor});

  factory AppThemeState.initial() {
    return const AppThemeState(
      themeMode: ThemeMode.system,
      accentColor: Color(0xFF6750A4),
    );
  }

  AppThemeState copyWith({ThemeMode? themeMode, Color? accentColor}) {
    return AppThemeState(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemeState &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          accentColor == other.accentColor;

  @override
  int get hashCode => themeMode.hashCode ^ accentColor.hashCode;
}
