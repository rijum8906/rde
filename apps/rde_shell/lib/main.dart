//! # RDE Shell Entry Point
//!
//! Boots the Wayland top panel and starts the Flutter app that draws it.

import 'package:flutter/material.dart';
import 'package:rde_shell/app.dart';
import 'package:rde_shell/core/bootstrap/window_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: configure the window as a top panel. On compositors without
  // zwlr_layer_shell_v1 the window stays a normal toplevel, so the panel still
  // runs; it just doesn't reserve screen space above maximised windows.
  // final bool isLayerSurface = await bootstrapShellWindow();

  // if (!isLayerSurface) {
  //   debugPrint(
  //     'rde_shell: layer shell unavailable, running as a normal window',
  //   );
  // }

  // Step 2: start the shell.
  runApp(const RdeShellApp());
}
