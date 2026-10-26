// Motion tokens for the RDE shell.
//
// Every animation in the shell pulls its duration and curve from here so the
// desktop feels consistent. The values follow the Material 3 Expressive model:
// short, springy entrances and quicker, decisive exits.

import 'package:flutter/animation.dart';

/// Shared motion tokens used across shell surfaces.
abstract final class ShellMotion {
  /// Time for a notification card to spring into place.
  static const Duration cardEntry = Duration(milliseconds: 560);

  /// Time for a notification card to leave the screen.
  static const Duration cardExit = Duration(milliseconds: 220);

  /// Time for the stack to reflow when a card is added or removed.
  static const Duration stackReflow = Duration(milliseconds: 260);

  /// Time for pointer-hover feedback.
  static const Duration hover = Duration(milliseconds: 140);

  /// Time for the "more notifications" chip to appear.
  static const Duration chipSwap = Duration(milliseconds: 180);

  /// Springy entrance curve; the small overshoot gives the Expressive feel.
  static const Curve entryCurve = Curves.easeOutBack;

  /// Decisive exit curve, so dismissed cards get out of the way quickly.
  static const Curve exitCurve = Curves.easeInCubic;

  /// Curve used when the stack reflows.
  static const Curve stackCurve = Curves.easeOutCubic;
}
