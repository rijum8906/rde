import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_theme_event.dart';
import 'app_theme_state.dart';

class AppThemeBloc extends Bloc<AppThemeEvent, AppThemeState> {
  AppThemeBloc() : super(AppThemeState.initial()) {
    on<ChangeThemeModeEvent>((event, emit) {
      emit(state.copyWith(themeMode: event.themeMode));
    });
    on<ChangeAccentColorEvent>((event, emit) {
      emit(state.copyWith(accentColor: event.accentColor));
    });
  }
}
