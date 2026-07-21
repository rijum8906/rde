class InterfaceAssetsSettings {
  final String iconPack;
  final String cursorTheme;
  final double scaleFactor;

  const InterfaceAssetsSettings({
    required this.iconPack,
    required this.cursorTheme,
    required this.scaleFactor,
  });

  InterfaceAssetsSettings copyWith({
    String? iconPack,
    String? cursorTheme,
    double? scaleFactor,
  }) {
    return InterfaceAssetsSettings(
      iconPack: iconPack ?? this.iconPack,
      cursorTheme: cursorTheme ?? this.cursorTheme,
      scaleFactor: scaleFactor ?? this.scaleFactor,
    );
  }
}
