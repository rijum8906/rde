// Controls the geometry of the shell's Wayland layer surface.
//
// The shell renders on a single, top-anchored layer surface. Notifications need
// room below the 40 px panel, so the surface is grown downwards while cards are
// visible and collapsed back once they are gone. The input region is kept in
// sync so the transparent area never swallows pointer events.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rde_shell/core/constants/app_layout.dart';
import 'package:wayland_layer_shell/wayland_layer_shell.dart';

/// Abstraction over the layer surface so widgets stay testable.
abstract interface class ShellSurface {
  /// Sets the height of the notification lane below the panel.
  ///
  /// A value of `0` collapses the surface back to the panel.
  Future<void> setNotificationLaneHeight(int height);
}

/// [ShellSurface] backed by the `wayland_layer_shell` platform channel.
///
/// Calls are serialised: the surface is resized and its input region updated
/// only after the previous request finished, so rapid notification bursts
/// cannot leave the compositor in an inconsistent state.
class WaylandShellSurface implements ShellSurface {
  /// Creates a controller around the layer-shell plugin.
  ///
  /// [plugin] is injectable for tests and alternate platform bindings.
  WaylandShellSurface({WaylandLayerShell? plugin})
    : _plugin = plugin ?? WaylandLayerShell();

  final WaylandLayerShell _plugin;
  Future<void> _pending = Future<void>.value();
  int _appliedLaneHeight = 0;

  @override
  Future<void> setNotificationLaneHeight(int height) {
    final int clamped = height < 0 ? 0 : height;
    if (clamped == _appliedLaneHeight) {
      return _pending;
    }
    _appliedLaneHeight = clamped;

    _pending = _pending.then((_) => _apply(clamped));
    return _pending;
  }

  Future<void> _apply(int height) async {
    final int surfaceHeight = initialPanelHeight + height;

    try {
      // Step 1: Resize the anchored layer surface. The exclusive zone stays at
      // the panel height, so maximised windows are not pushed around.
      await _plugin.setSurfaceHeight(surfaceHeight);

      // Step 2: Only the panel and the notification lane accept pointer input;
      // everything below the lane passes clicks through to the desktop.
      await _plugin.setInputRegion(x: 0, y: 0, height: surfaceHeight);
    } on MissingPluginException {
      // Running outside a Wayland layer surface (tests, other platforms).
      debugPrint('ShellSurface: layer shell unavailable, geometry unchanged');
    } on PlatformException catch (error) {
      debugPrint('ShellSurface: failed to resize surface: $error');
    }
  }
}

/// [ShellSurface] that ignores every request.
///
/// Used by widget tests and previews where no layer surface exists.
class NoopShellSurface implements ShellSurface {
  /// Creates a no-op surface controller.
  const NoopShellSurface();

  @override
  Future<void> setNotificationLaneHeight(int height) async {}
}
