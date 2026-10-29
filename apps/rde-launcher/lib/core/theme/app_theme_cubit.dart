import 'dart:async';

import 'package:core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// # App Theme Cubit
///
/// Applies the cached desktop theme immediately and follows later publications
/// from the shared `org.rde.Theme` service.
class AppThemeCubit extends Cubit<ThemeData> {
  /// Creates a theme controller with a first-frame-ready [initialTheme].
  AppThemeCubit(super.initialTheme, {RdeThemeProxy? proxy})
    : _proxy = proxy ?? RdeThemeProxy();

  final RdeThemeProxy _proxy;
  StreamSubscription<ThemeChangedSignal>? _subscription;

  /// Subscribes to theme updates and reconciles with the service's current value.
  Future<void> synchronize() async {
    try {
      _subscription = _proxy.watchThemeChanges().listen(
        (signal) => _applyPublishedTheme(signal),
        onError: (Object error) {
          debugPrint('Launcher theme signal failed: $error');
        },
      );
    } catch (error) {
      debugPrint('Unable to subscribe to launcher theme updates: $error');
    }
    await _applyPublishedTheme();
  }

  Future<void> _applyPublishedTheme([ThemeChangedSignal? signal]) async {
    final result = await _proxy.fetchResolvedTheme();
    final resolved = result.fold((failure) {
      if (signal == null) {
        debugPrint('Unable to load desktop theme: ${failure.message}');
        return null;
      }
      return ResolvedTheme.tryFromJsonString(signal.resolvedJson);
    }, (theme) => theme);
    if (resolved == null || isClosed) {
      return;
    }

    final modeResult = await _proxy.fetchMode();
    final mode = modeResult.fold((failure) {
      debugPrint('Unable to read theme appearance: ${failure.message}');
      return AppearanceMode.fromSurface(resolved.colors.surface);
    }, (mode) => mode);
    if (!isClosed) {
      emit(buildRdeTheme(resolved, mode: mode));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
