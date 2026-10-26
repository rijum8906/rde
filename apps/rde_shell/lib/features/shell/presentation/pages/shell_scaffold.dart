// Root layout of the RDE shell surface.

import 'package:flutter/material.dart';
import 'package:rde_shell/core/constants/app_layout.dart';
import 'package:rde_shell/core/shell/shell_surface.dart';
import 'package:rde_shell/features/notifications/presentation/widgets/notification_host.dart';
import 'package:rde_shell/features/shell/presentation/widgets/shell_panel.dart';

/// Lays out the panel and the notification lane on the transparent surface.
///
/// A [Stack] is used rather than a [Column] so the notification lane can render
/// above the current surface bounds for the frame before the Wayland surface is
/// resized; the compositor clips it and the next frame is already larger.
class ShellScaffold extends StatelessWidget {
  /// Creates the shell scaffold.
  const ShellScaffold({required this.surface, super.key});

  /// Surface controller shared with the notification host.
  final ShellSurface surface;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: initialPanelHeight.toDouble(),
            child: const ShellPanel(),
          ),
          Positioned(
            top: initialPanelHeight.toDouble(),
            left: 0,
            right: 0,
            child: NotificationHost(surface: surface),
          ),
        ],
      ),
    );
  }
}
