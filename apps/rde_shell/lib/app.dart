//! # Rde Shell App
//!
//! Minimal desktop panel

import 'package:flutter/material.dart';
import 'package:rde_shell/core/constants/app_layout.dart';

class RdeShellApp extends StatelessWidget {
  const RdeShellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Container(
        height: initialPanelHeight.toDouble(),
        color: Colors.blueGrey[900],
        child: const Center(
          child: Text('RDE Shell', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
