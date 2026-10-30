import 'package:flutter/animation.dart';
import 'package:silky_scroll/silky_scroll.dart';

/// The one scroll feel the app uses.
///
/// silky_scroll's own default runs 1600 ms per notch, which reads as lag on a
/// settings page: 700 ms with an ease-out curve arrives before the eye starts
/// waiting, and both values live here so the whole app can be retuned in one
/// place.
const SilkyScrollConfig appSilkyScroll = SilkyScrollConfig(
  silkyScrollDuration: Duration(milliseconds: 700),
  animationCurve: Curves.easeOutCubic,
);
