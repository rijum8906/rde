class WallpaperSettings {
  final String sourcePath;
  final String fitMode;
  final int slideshowInterval;

  const WallpaperSettings({
    required this.sourcePath,
    required this.fitMode,
    required this.slideshowInterval,
  });

  WallpaperSettings copyWith({
    String? sourcePath,
    String? fitMode,
    int? slideshowInterval,
  }) {
    return WallpaperSettings(
      sourcePath: sourcePath ?? this.sourcePath,
      fitMode: fitMode ?? this.fitMode,
      slideshowInterval: slideshowInterval ?? this.slideshowInterval,
    );
  }
}
