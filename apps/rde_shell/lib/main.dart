// Entry point of the RDE shell.

import 'package:flutter/material.dart';
import 'package:rde_shell/app.dart';
import 'package:rde_shell/core/bootstrap/window_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool isSupported = await bootstrapShellWindow();

  if (!isSupported) {
    debugPrint('RDE Shell requires a compositor with zwlr_layer_shell_v1');
    return;
  }

  runApp(const RdeShellApp());
}
