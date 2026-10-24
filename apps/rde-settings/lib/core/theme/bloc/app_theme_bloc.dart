import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_theme_event.dart';
import 'app_theme_state.dart';

class AppThemeBloc extends Bloc<AppThemeEvent, AppThemeState> {
  AppThemeBloc() : super(AppThemeState.initial()) {
    on<ChangeThemeModeEvent>((event, emit) {
      emit(state.copyWith(themeMode: event.themeMode));
    });
    on<ChangeAccentColorEvent>((event, emit) {
      // A locally picked accent has no service palette behind it, so drop the
      // generated schemes and let the seed color build the theme again.
      emit(state.copyWith(accentColor: event.accentColor, clearSchemes: true));
    });
    on<ApplySystemPaletteEvent>((event, emit) {
      // Follow the desktop scheme and adopt both generated palettes.
      emit(
        state.copyWith(
          lightScheme: event.lightScheme,
          darkScheme: event.darkScheme,
          accentColor: Color(event.sourceColorArgb),
          themeMode: event.isDark ? ThemeMode.dark : ThemeMode.light,
        ),
      );
    });
  }
}
