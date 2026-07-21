class TypographySettings {
  final String systemFont;
  final String monoFont;
  final double fontSize;
  final bool subpixelAntialiasing;

  const TypographySettings({
    required this.systemFont,
    required this.monoFont,
    required this.fontSize,
    required this.subpixelAntialiasing,
  });

  TypographySettings copyWith({
    String? systemFont,
    String? monoFont,
    double? fontSize,
    bool? subpixelAntialiasing,
  }) {
    return TypographySettings(
      systemFont: systemFont ?? this.systemFont,
      monoFont: monoFont ?? this.monoFont,
      fontSize: fontSize ?? this.fontSize,
      subpixelAntialiasing: subpixelAntialiasing ?? this.subpixelAntialiasing,
    );
  }
}
