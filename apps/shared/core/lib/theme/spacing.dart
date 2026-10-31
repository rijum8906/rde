import 'package:flutter/material.dart';

/// Defines universal spacing tokens for the app.
/// Access these via `Theme.of(context).extension<AppSpacing>()!`
@immutable
class Spacing extends ThemeExtension<Spacing> {
  final double xs; // 4.0
  final double sm; // 8.0
  final double md; // 16.0
  final double lg; // 24.0
  final double xl; // 32.0

  const Spacing({
    this.xs = 4.0,
    this.sm = 8.0,
    this.md = 16.0,
    this.lg = 24.0,
    this.xl = 32.0,
  });

  @override
  Spacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
  }) {
    return Spacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }

  @override
  Spacing lerp(ThemeExtension<Spacing>? other, double t) {
    if (other is! Spacing) return this;
    return Spacing(
      xs: lerpDouble(xs, other.xs, t),
      sm: lerpDouble(sm, other.sm, t),
      md: lerpDouble(md, other.md, t),
      lg: lerpDouble(lg, other.lg, t),
      xl: lerpDouble(xl, other.xl, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
