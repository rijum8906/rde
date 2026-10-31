import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/theme.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus_theme_datasource.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository_impl.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/views/theme_styling_view.dart';

class ThemeStylingPage extends StatelessWidget {
  const ThemeStylingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = ThemeRepositoryImpl(
      DbusThemeDatasource(RdeThemeProxy()),
    );

    return BlocProvider(
      create: (_) => ThemeBloc(repository: repository)
        ..add(const ThemeInitEvent()),
      child: const ThemeStylingView(),
    );
  }
}
