import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_bloc.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_event.dart';
import 'package:core/theme.dart';

/// Keeps the settings app in sync with the theme published by `org.rde.Theme`.
///
/// Startup reads the on-disk cache in `main()` before the first frame, so this
/// sync only has to follow later publications. Each `PropertiesChanged`
/// notification carries the payload the service read back for it, and the
/// appearance is the variant that payload was resolved for.
///
/// # Parameters
/// - [appThemeBloc]: global bloc wrapping the `MaterialApp` theme
///
/// # Returns
/// The payload subscription, or `null` when the session bus rejected it.
Future<StreamSubscription<ResolvedTheme>?> syncSystemTheme(
  AppThemeBloc appThemeBloc,
) async {
  final proxy = RdeThemeProxy();

  // Step 1: Subscribe before any read, so a publication that lands between the
  // startup read and the subscription is not missed.
  StreamSubscription<ResolvedTheme>? subscription;
  try {
    subscription = proxy.watchResolvedTheme().listen(
      (resolved) => _apply(appThemeBloc, resolved),
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

/// Reads the current payload from the service.
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

  await _apply(appThemeBloc, resolved);
}

/// Applies [resolved] with the appearance it was resolved for.
Future<void> _apply(AppThemeBloc appThemeBloc, ResolvedTheme resolved) async {
  appThemeBloc.add(
    ApplyResolvedThemeEvent(
      resolved: resolved,
      mode: AppearanceMode.fromDbus(resolved.variant),
    ),
  );
}
