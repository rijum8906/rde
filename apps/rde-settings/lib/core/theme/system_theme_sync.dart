import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_bloc.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_event.dart';
import 'package:core/theme.dart';

/// Keeps the settings app in sync with the theme published by `org.rde.Theme`.
///
/// Startup reads the on-disk cache in `main()` before the first frame, so this
/// sync only has to follow later publications. The `ThemeChanged` signal is
/// treated as a notification, not as the payload: every signal triggers a fresh
/// `GetResolvedTheme` call, which always observes the durable payload the
/// service wrote before signalling.
///
/// # Parameters
/// - [appThemeBloc]: global bloc wrapping the `MaterialApp` theme
///
/// # Returns
/// The signal subscription, or `null` when the session bus rejected it.
Future<StreamSubscription<ThemeChangedSignal>?> syncSystemTheme(
  AppThemeBloc appThemeBloc,
) async {
  final proxy = RdeThemeProxy();

  // Step 1: Subscribe before any read, so a publication that lands between the
  // startup read and the subscription is not missed.
  StreamSubscription<ThemeChangedSignal>? subscription;
  try {
    subscription = proxy.watchThemeChanges().listen(
      (signal) => _reloadFromSignal(appThemeBloc, proxy, signal),
      onError: (Object error) {
        debugPrint('org.rde.Theme signal subscription failed: $error');
      },
    );
  } catch (error) {
    debugPrint('Unable to subscribe to org.rde.Theme changes: $error');
  }

  // Step 2: Reconcile the cached payload with the service. `main()` already
  // applied the cache, so this only corrects a cache that was stale or missing.
  await _reloadFromService(appThemeBloc, proxy);

  return subscription;
}

/// Reloads the published theme after a `ThemeChanged` signal.
///
/// The service writes the payload to disk before signalling, so the
/// authoritative read is `GetResolvedTheme`; the signal JSON is only a fallback
/// for a transient call failure.
Future<void> _reloadFromSignal(
  AppThemeBloc appThemeBloc,
  RdeThemeProxy proxy,
  ThemeChangedSignal signal,
) async {
  // Step 1: Prefer the service read, exactly like a cold startup.
  final result = await proxy.fetchResolvedTheme();
  final resolved = result.fold((failure) {
    debugPrint(
      'Unable to read the published theme after a signal, using the signal '
      'payload: ${failure.message}',
    );
    return ResolvedTheme.tryFromJsonString(signal.resolvedJson);
  }, (resolved) => resolved);

  if (resolved == null) {
    debugPrint('Ignoring an unreadable org.rde.Theme payload');
    return;
  }

  // Step 2: Apply it with the appearance it was resolved for.
  await _apply(appThemeBloc, proxy, resolved);
}

/// Reads the current payload and appearance from the service.
Future<void> _reloadFromService(
  AppThemeBloc appThemeBloc,
  RdeThemeProxy proxy,
) async {
  final result = await proxy.fetchResolvedTheme();
  final resolved = result.fold((failure) {
    debugPrint('Unable to read the org.rde.Theme payload: ${failure.message}');
    return null;
  }, (resolved) => resolved);

  if (resolved == null) {
    return;
  }

  await _apply(appThemeBloc, proxy, resolved);
}

/// Applies [resolved] together with the appearance the service publishes.
Future<void> _apply(
  AppThemeBloc appThemeBloc,
  RdeThemeProxy proxy,
  ResolvedTheme resolved,
) async {
  // Step 1: Ask for the appearance; fall back to the surface luminance when
  // the property cannot be read so a transient bus error cannot flip the app.
  final modeResult = await proxy.fetchMode();
  final mode = modeResult.fold((failure) {
    debugPrint(
      'Unable to read the org.rde.Theme mode, inferring it from the surface '
      'color: ${failure.message}',
    );
    return AppearanceMode.fromSurface(resolved.colors.surface);
  }, (mode) => mode);

  // Step 2: Hand the complete payload to the app theme bloc.
  appThemeBloc.add(ApplyResolvedThemeEvent(resolved: resolved, mode: mode));
}
