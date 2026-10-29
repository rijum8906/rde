//! # Window Bootstrap
//!
//! Turns the Flutter window into a fixed-height Wayland top panel: the surface
//! is anchored to the top edge and reserves an exclusive zone, so maximised
//! windows stop at the panel's bottom edge.

import 'package:wayland_layer_shell/types.dart';
import 'package:wayland_layer_shell/wayland_layer_shell.dart';
import 'package:rde_shell/core/constants/app_layout.dart';

/// Configures the window as the RDE top panel.
///
/// Returns `true` when the surface is a layer-shell panel, or `false` when the
/// compositor doesn't implement `zwlr_layer_shell_v1` (GNOME, KDE Plasma,
/// non-Wayland sessions) and the window stays a normal toplevel.
Future<bool> bootstrapShellWindow() async {
  final WaylandLayerShell plugin = WaylandLayerShell();

  // Step 1: initialize the layer surface. The native side only creates one if
  // the compositor advertises zwlr_layer_shell_v1.
  final bool supported = await plugin.initialize();
  if (!supported) {
    return false;
  }

  // Step 2: pin the surface to the top edge and stretch it across the screen.
  await plugin.setLayer(ShellLayer.layerTop);
  await plugin.setAnchor(ShellEdge.edgeLeft, true);
  await plugin.setAnchor(ShellEdge.edgeRight, true);
  await plugin.setAnchor(ShellEdge.edgeTop, true);
  await plugin.setAnchor(ShellEdge.edgeBottom, false);

  // Step 3: give the panel its height and reserve that height with the
  // compositor so maximised windows are not covered.
  await plugin.setSurfaceHeight(panelHeight);
  await plugin.setExclusiveZone(panelHeight);

  // Step 4: a panel must never take keyboard focus away from app windows.
  await plugin.setKeyboardMode(ShellKeyboardMode.keyboardModeNone);

  return true;
}
