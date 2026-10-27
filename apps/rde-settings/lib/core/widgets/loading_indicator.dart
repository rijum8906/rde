import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';

/// Material 3 Expressive loading indicator used across the settings app.
///
/// The expressive design replaces the flat spinner with a shape that morphs
/// between rounded polygons while it rotates, so every wait in the app looks
/// like the same component. [size] gives the square the indicator occupies,
/// which lets an inline spot such as a refresh button share the same widget.
class RdeLoadingIndicator extends StatelessWidget {
  /// Creates an expressive loading indicator.
  ///
  /// # Parameters
  /// - [size]: edge length of the square the indicator occupies.
  /// - [color]: color of the morphing shape; defaults to the theme's primary
  ///   color.
  /// - [semanticsLabel]: label announced by assistive technology.
  const RdeLoadingIndicator({
    super.key,
    this.size = 48,
    this.color,
    this.semanticsLabel = 'Loading',
  });

  /// Edge length of the square the indicator occupies.
  final double size;

  /// Color of the morphing shape, or `null` to follow the theme.
  final Color? color;

  /// Label announced by assistive technology.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    // Step 1: The package animates inside the box it is given, so the requested
    // size is passed as tight constraints instead of a wrapping SizedBox.
    return ExpressiveLoadingIndicator(
      constraints: BoxConstraints.tightFor(width: size, height: size),
      color: color,
      semanticsLabel: semanticsLabel,
    );
  }
}
