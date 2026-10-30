/// # RDE Launcher Entry Point
///
/// Seeds the shared desktop theme, configures the window, and starts the
/// launcher app.
library;

import 'dart:io';

import 'package:core/theme.dart';
import 'package:flutter/material.dart';
import 'package:rde_launcher/app.dart';
import 'package:rde_launcher/core/bootstrap/window_bootstrap.dart';
import 'package:rde_launcher/features/app_search/data/repositories/desktop_application_repository.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/find_applications.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/launch_application.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/load_applications.dart';

/// Starts the Linux desktop application launcher.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: Size and center the window before the first frame.
  await bootstrapLauncherWindow();

  // Step 2: Seed the first frame from the shared theme cache when available.
  final cachedTheme = const RdeThemeCache().read();
  final initialTheme = cachedTheme == null
      ? ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: Brightness.light,
          ),
        )
      : buildRdeTheme(
          cachedTheme,
          mode: AppearanceMode.fromSurface(cachedTheme.colors.surface),
        );

  // Step 3: Load the XDG application menu through its feature repository.
  const repository = DesktopApplicationRepository();
  final loadApplications = LoadApplications(repository);
  final findApplications = FindApplications();
  final launchApplication = LaunchApplication(repository);

  runApp(
    RdeLauncherApp(
      initialTheme: initialTheme,
      loadApplications: loadApplications,
      findApplications: findApplications,
      launchApplication: launchApplication,
      // Escape with an empty search dismisses the launcher process.
      onClose: () => exit(0),
    ),
  );
}
