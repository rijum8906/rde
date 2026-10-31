import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/theme.dart';

import 'app_theme_event.dart';
import 'app_theme_state.dart';

/// Owns the application-wide theme of the settings app.
///
/// The desktop theme published by `org.rde.Theme` always wins: it is applied on
/// startup by the system theme sync and refreshed from the `ThemeChanged`
/// signal. Local events remain available for screens that only restyle this
/// window.
class AppThemeBloc extends Bloc<AppThemeEvent, AppThemeState> {
  AppThemeBloc() : super(AppThemeState.initial()) {
    on<ChangeThemeModeEvent>((event, emit) {
      emit(state.copyWith(appearanceMode: event.appearanceMode));
    });
    on<ChangeAccentColorEvent>((event, emit) {
      // A locally picked accent has no service payload behind it, so drop the
      // resolved theme and let the seed color build the schemes again.
      emit(
        state.copyWith(
          accentColor: event.accentColor,
          clearResolvedTheme: true,
        ),
      );
    });
    on<ApplyResolvedThemeEvent>((event, emit) {
      // Step 1: Build the complete ThemeData from the desktop payload.
      final theme = RdeThemeBuilder.fromResolvedTheme(
        event.resolved,
        event.mode,
      );

      // Step 2: Publish it together with the appearance it was resolved for.
      emit(
        state.copyWith(
          resolvedTheme: event.resolved,
          theme: theme,
          accentColor: event.resolved.colors.primary.toColor(),
          appearanceMode: event.mode.isDark
              ? AppearanceMode.dark
              : AppearanceMode.light,
        ),
      );
    });
  }
}
