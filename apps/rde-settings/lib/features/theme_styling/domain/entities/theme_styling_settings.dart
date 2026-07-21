class ThemeStylingSettings {
  final String themeMode;
  final String accentColor;
  final String themePack;

  const ThemeStylingSettings({
    required this.themeMode,
    required this.accentColor,
    required this.themePack,
  });

  ThemeStylingSettings copyWith({
    String? themeMode,
    String? accentColor,
    String? themePack,
  }) {
    return ThemeStylingSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      themePack: themePack ?? this.themePack,
    );
  }
}
