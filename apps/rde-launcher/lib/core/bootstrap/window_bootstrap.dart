/// # Window Bootstrap
///
/// Configures the launcher toplevel through `window_manager`: a frameless,
/// fixed 1000x700 window centered on the desktop.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Fixed size of the launcher window.
const Size launcherWindowSize = Size(1000, 700);

/// Prepares and shows the launcher window.
///
/// The window is hidden until the requested size and position are applied, so
/// it never flashes at the toolkit's default geometry. Failures are logged and
/// leave the window usable at its fallback size instead of aborting startup.
///
/// # Ordering
///
/// The window is made **resizable** during setup and only frozen after the
/// size is committed. `setResizable(false)` on GTK triggers a re-evaluation
/// of the window's natural size; if the size has not been applied yet, GTK
/// shrinks the window to the Flutter view's tiny intrinsic size. Applying
/// `setSize` *after* `setResizable(false)` would fix that but causes a
/// visible one-frame shrink on some compositors. The current order (size,
/// then freeze) avoids both.
Future<void> bootstrapLauncherWindow() async {
  try {
    // Step 1: Initialize the platform window plugin before any geometry call.
    await windowManager.ensureInitialized();

    // Step 2: Apply the fixed geometry immediately, then show the window once
    // the first frame is ready. This future must not be awaited before
    // `runApp`, because it only completes after the first frame is rendered.
    unawaited(
      windowManager.waitUntilReadyToShow(
        const WindowOptions(
          size: launcherWindowSize,
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: true,
          title: 'RDE Launcher',
        ),
        () async {
          // Step 1: Frameless + minimum size first. GTK sizes a non-resizable
          // window to its natural size, which for the Flutter view is tiny
          // unless a minimum exists; the minimum is what keeps the window
          // from collapsing when `setResizable(false)` runs below.
          await windowManager.setAsFrameless();
          await windowManager.setMinimumSize(launcherWindowSize);

          // Step 2: Show and focus. The window becomes visible now, at the
          // size applied in the next step. The show happens before the
          // freeze so the compositor never has to re-negotiate the size of
          // an already-visible window.
          await windowManager.show();
          await windowManager.center();
          await windowManager.focus();

          // Step 3: Commit the size, then freeze. `setSize` after `show` is
          // what the user sees; `setResizable(false)` is last so its
          // internal size re-evaluation uses the size just committed, not
          // the Flutter view's intrinsic size.
          await windowManager.setSize(launcherWindowSize);
          await windowManager.setResizable(false);
        },
      ),
    );
  } catch (error, stackTrace) {
    // Startup continues even when the window plugin is unavailable; the
    // GTK runner's default size (1000×700, set in `my_application.cc`)
    // keeps the window usable.
    debugPrint('Unable to configure the launcher window: $error\n$stackTrace');
  }
}
