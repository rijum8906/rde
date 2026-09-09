import 'package:flutter/material.dart';
import 'package:rde_shell/core/bootstrap/window_bootstrap.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isSupported = await bootstrapShellWindow();

  if (!isSupported) {
    debugPrint('❌ Wayland Layer Shell not supported');
    return;
  }

  runApp(const RdeShellApp());
}
