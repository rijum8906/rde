import 'package:core/theme/domain/entities/theme_color.dart';
import 'package:flutter/material.dart';

/// Material seed colors offered as palette regeneration options.
const List<String> kSeedColors = [
  '#6750A4',
  '#0061A4',
  '#006E3C',
  '#B52700',
  '#7E5700',
  '#B90063',
  '#006874',
  '#4F6310',
  '#984061',
  '#3F51B5',
  '#E91E63',
  '#009688',
];

/// Parses a hex color for display, falling back to the Material seed.
Color displayColor(String hex) =>
    Color(ThemeColor.parseArgb(hex) ?? 0xFF6750A4);
