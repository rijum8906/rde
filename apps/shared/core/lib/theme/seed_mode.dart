import 'package:flutter/material.dart';

/// How the dynamic theme's four seeds are chosen.
enum SeedMode {
  dynamic(
    'Dynamic',
    'Colours are extracted from the current wallpaper.',
    Icons.wallpaper,
  ),
  custom(
    'Custom',
    'Pick one accent; the other families are derived from it.',
    Icons.palette_outlined,
  );

  const SeedMode(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}
