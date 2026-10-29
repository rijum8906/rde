//! # RDE Shell App
//!
//! Root widget that applies the shell theme and hosts the top panel.

import 'package:flutter/material.dart';
import 'package:rde_shell/core/theme/app_theme.dart';
import 'package:rde_shell/panel/shell_panel.dart';

/// Root widget of the RDE desktop shell.
class RdeShellApp extends StatelessWidget {
  /// Creates the shell app.
  const RdeShellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RDE Shell',
      theme: AppTheme.dark(),
      home: const Material(
        type: MaterialType.transparency,
        child: ShellPanel(),
      ),
    );
  }
}
