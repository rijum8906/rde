import 'package:wayland_layer_shell/types.dart';
import 'package:wayland_layer_shell/wayland_layer_shell.dart';
import 'package:rde_shell/core/constants/app_layout.dart';
import 'package:flutter/foundation.dart';

/// Configures the window as the RDE top panel.
Future<bool> bootstrapShellWindow() async {
  final WaylandLayerShell plugin = WaylandLayerShell();

  final bool supported = await plugin.initialize();
  if (!supported) {
    return false;
  }

  // 1. Anchor to all edges EXCEPT bottom.
  // This makes the surface stretch to fill the whole screen height.
  await plugin.setLayer(ShellLayer.layerTop);
  await plugin.setAnchor(ShellEdge.edgeLeft, true);
  await plugin.setAnchor(ShellEdge.edgeRight, true);
  await plugin.setAnchor(ShellEdge.edgeTop, true);
  await plugin.setAnchor(ShellEdge.edgeBottom, true); // Stretch to bottom

  // 2. Tell the compositor to reserve ONLY 40px for normal windows.
  // The rest of the surface is transparent and click-through.
  await plugin.setExclusiveZone(panelHeight); // 40px

  // 3. Set the visual surface size to full screen height.
  await plugin.setSurfaceHeight(2000); // A large number to force full height

  await plugin.setKeyboardMode(ShellKeyboardMode.keyboardModeNone);

  return true;
}
