import 'package:flutter/material.dart';
import 'package:rde_shell/core/theme/app_theme.dart';
import 'package:rde_shell/panel/shell_panel.dart';

class RdeShellApp extends StatelessWidget {
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
