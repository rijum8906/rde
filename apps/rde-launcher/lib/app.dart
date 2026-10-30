/// # RDE Launcher App
///
/// Root widget that applies the shared desktop theme and hosts the launcher
/// feature surface.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_launcher/core/theme/app_theme_cubit.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/find_applications.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/launch_application.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/load_applications.dart';
import 'package:rde_launcher/features/app_search/presentation/bloc/app_search_bloc.dart';
import 'package:rde_launcher/features/app_search/presentation/pages/launcher_page.dart';

/// Root app shell for RDE Launcher.
class RdeLauncherApp extends StatelessWidget {
  /// Creates the launcher app with its initial theme and feature use cases.
  ///
  /// # Parameters
  /// - [initialTheme]: theme applied before the desktop theme service answers.
  /// - [loadApplications]: installed application discovery use case.
  /// - [findApplications]: search/filter use case.
  /// - [launchApplication]: desktop application launch use case.
  /// - [onClose]: invoked when the user dismisses the launcher with Escape.
  const RdeLauncherApp({
    required this.initialTheme,
    required this.loadApplications,
    required this.findApplications,
    required this.launchApplication,
    this.onClose,
    super.key,
  });

  /// Theme applied before the shared desktop theme service responds.
  final ThemeData initialTheme;

  /// Installed application discovery use case.
  final LoadApplications loadApplications;

  /// Search/filter use case.
  final FindApplications findApplications;

  /// Desktop application launch use case.
  final LaunchApplication launchApplication;

  /// Invoked when the user dismisses the launcher with Escape.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppThemeCubit(initialTheme)..synchronize(),
      child: BlocBuilder<AppThemeCubit, ThemeData>(
        builder: (context, theme) {
          return MaterialApp(
            title: 'RDE Launcher',
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: BlocProvider(
              create: (_) => AppSearchBloc(
                loadApplications: loadApplications,
                findApplications: findApplications,
                launchApplication: launchApplication,
              ),
              child: LauncherPage(onClose: onClose),
            ),
          );
        },
      ),
    );
  }
}
