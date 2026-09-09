//! # Window Bootstrap
//!
//! Initializes wayland layer shell and window for the desktop panel
//!
//! ## Features
//! - Centralizes all the initialization and setup process to run the shell app
//! - Configures the panel as a proper Wayland layer surface
//! - Handles exclusive zones for maximized windows
//!
//! ## Related
//! - RdeShellApp
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal <rijum8906@gmail.com>. All rights reserved.

import 'package:flutter/material.dart';
import 'package:rde_shell/core/constants/app_layout.dart';
import 'package:wayland_layer_shell/types.dart';
import 'package:wayland_layer_shell/wayland_layer_shell.dart';

/// Bootstrap the Wayland shell window with all necessary configurations
///
/// This function:
/// 1. Initializes the Wayland Layer Shell
/// 2. Configures the panel as a TOP layer surface
/// 3. Sets exclusive zone so maximized windows avoid the panel
/// 4. Hides the title bar and window decorations
/// 5. Makes the panel always on top
Future<bool> bootstrapShellWindow() async {
  try {
    // STEP 1: Ensure Flutter is initialized
    WidgetsFlutterBinding.ensureInitialized();

    // STEP 2: Regular window-manager APIs are not valid for a layer-surface
    // desktop panel and can break the compositor's initial configure handshake.

    // STEP 3: Initialize Wayland Layer Shell
    final waylandLayerShellPlugin = WaylandLayerShell();
    final isSupported = await waylandLayerShellPlugin.initialize();

    if (!isSupported) {
      debugPrint('❌ Wayland Layer Shell not supported on this compositor');
      return false;
    }

    debugPrint('✅ Wayland Layer Shell initialized successfully');

    // Configure the layer surface in order and wait for each native call to
    // complete before the compositor is asked to show/render the window.
    await waylandLayerShellPlugin.setLayer(ShellLayer.layerTop);
    await waylandLayerShellPlugin.setAnchor(ShellEdge.edgeLeft, true);
    await waylandLayerShellPlugin.setAnchor(ShellEdge.edgeRight, true);
    await waylandLayerShellPlugin.setAnchor(ShellEdge.edgeTop, true);
    await waylandLayerShellPlugin.setAnchor(ShellEdge.edgeBottom, false);
    await waylandLayerShellPlugin.setSurfaceHeight(initialPanelHeight);
    await waylandLayerShellPlugin.setExclusiveZone(initialPanelHeight.toInt());
    await waylandLayerShellPlugin.setKeyboardMode(
      ShellKeyboardMode.keyboardModeExclusive,
    );
    // The compositor owns the final layer-surface policy for the panel. Keep it
    // fully layer-shell driven instead of reconfiguring it as a normal app window.

    debugPrint('✅ Shell panel configured successfully');
    debugPrint('   📐 Height: ${initialPanelHeight}px');
    debugPrint('   📌 Exclusive Zone: ${initialPanelHeight}px');
    debugPrint('   🔝 Layer: Top');
    debugPrint('   📍 Anchors: Left, Right, Top');

    return true;
  } catch (e) {
    debugPrint('❌ Failed to bootstrap shell window: $e');
    return false;
  }
}

/// Resize the panel dynamically (for expansion/collapse)
///
/// Use this when you want to expand the panel (e.g., for music controls)
Future<void> resizePanel(int newHeight) async {
  try {
    final waylandLayerShellPlugin = WaylandLayerShell();

    // Update the surface height and exclusive zone in order and wait for each
    // call to complete so the compositor sees a valid layer-surface state.
    await waylandLayerShellPlugin.setSurfaceHeight(newHeight);
    await waylandLayerShellPlugin.setExclusiveZone(newHeight.toInt());

    debugPrint('📐 Panel resized to ${newHeight}px');
  } catch (e) {
    debugPrint('❌ Failed to resize panel: $e');
  }
}

/// Toggle the panel visibility (for fullscreen apps or hiding)
Future<void> setPanelVisibility(bool visible) async {
  try {
    final waylandLayerShellPlugin = WaylandLayerShell();

    if (visible) {
      // Show the panel
      await waylandLayerShellPlugin.setSurfaceHeight(initialPanelHeight);
      await waylandLayerShellPlugin.setExclusiveZone(
        initialPanelHeight.toInt(),
      );
    } else {
      // Hide the panel (set height to 0)
      await waylandLayerShellPlugin.setSurfaceHeight(0);
      await waylandLayerShellPlugin.setExclusiveZone(0);
    }

    debugPrint('👁️ Panel visibility: ${visible ? "visible" : "hidden"}');
  } catch (e) {
    debugPrint('❌ Failed to toggle panel visibility: $e');
  }
}
