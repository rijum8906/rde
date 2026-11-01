//! # RDE Shell Entry Point
//!
//! Boots the Wayland top panel and starts the Flutter app that draws it.

import 'package:flutter/material.dart';
import 'package:rde_shell/app.dart';
import 'package:rde_shell/core/bootstrap/window_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure the window as a top panel.
  final bool isLayerSurface = await bootstrapShellWindow();

  if (!isLayerSurface) {
    debugPrint(
      'rde_shell: layer shell unavailable, running as a normal window',
    );
  }

  runApp(const RdeShellApp());
}
