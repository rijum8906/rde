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
    'Choose your own color for each palette family.',
    Icons.palette_outlined,
  );

  const SeedMode(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}
