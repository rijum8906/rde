import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_bloc.dart';
import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/utils/accent_seeds.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/views/theme_styling_view.dart';

import 'theme_test_harness.dart';

/// Handles created inside the test body so every asynchronous callback stays
/// in the widget test's fake-async zone.
class _Harness {
  const _Harness({
    required this.repository,
    required this.themeBloc,
    required this.appThemeBloc,
  });

  final FakeThemeRepository repository;
  final ThemeBloc themeBloc;
  final AppThemeBloc appThemeBloc;
}

void main() {
  Future<_Harness> pumpView(WidgetTester tester) async {
    // Render on a desktop-sized surface so the two-column layout and the
    // installed-theme rows stay inside the viewport.
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = FakeThemeRepository();
    final themeBloc = buildThemeBloc(repository);
    final appThemeBloc = AppThemeBloc();
    addTearDown(() {
      themeBloc.close();
      appThemeBloc.close();
      repository.dispose();
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AppThemeBloc>.value(value: appThemeBloc),
          BlocProvider<ThemeBloc>.value(value: themeBloc),
        ],
        child: const MaterialApp(home: ThemeStylingView()),
      ),
    );

    // Load after the view is mounted, like ThemeStylingPage does.
    themeBloc.add(const ThemeInitEvent());
    await tester.pumpAndSettle();

    return _Harness(
      repository: repository,
      themeBloc: themeBloc,
      appThemeBloc: appThemeBloc,
    );
  }

  testWidgets('renders the installed themes from the catalog', (tester) async {
    await pumpView(tester);

    expect(find.text('Theme & Styling'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Installed Themes'), findsOneWidget);
    expect(find.text('Default'), findsWidgets);
    expect(find.text('Ocean'), findsOneWidget);
    expect(find.text('Live Preview'), findsOneWidget);
    expect(find.text('Palette roles'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders the payload published by the service', (tester) async {
    final harness = await pumpView(tester);

    expect(
      harness.themeBloc.state.catalog?.resolved.colors.primary.toColor(),
      const Color(0xFF6DD6DA),
    );
    expect(
      harness.themeBloc.state.previewTheme?.colors.primary.toColor(),
      const Color(0xFF6DD6DA),
    );
  });

  testWidgets('activating another theme calls the service', (tester) async {
    final harness = await pumpView(tester);

    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();

    expect(harness.repository.calls, contains('setTheme:ocean'));
    expect(harness.themeBloc.state.catalog?.currentTheme, 'ocean');
  });

  testWidgets('picking a custom accent derives all four seeds', (tester) async {
    final harness = await pumpView(tester);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    // Custom mode exposes a single accent option instead of one control per
    // palette family.
    final accentControl = find.text('Accent color');
    expect(accentControl, findsOneWidget);

    await tester.ensureVisible(accentControl);
    await tester.tap(accentControl);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '#0061A4');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final expected = seedsFromAccent('#0061A4');
    expect(
      harness.repository.calls,
      contains(
        'updateDynamicTheme:${expected.primary}:${expected.secondary}:'
        '${expected.tertiary}:${expected.error}',
      ),
    );
    expect(harness.themeBloc.state.dynamicSeeds, expected);
  });

  testWidgets('selecting the light appearance calls the service', (
    tester,
  ) async {
    final harness = await pumpView(tester);

    // The appearance card comes before the preview's scheme selector.
    await tester.tap(find.text('Light').first);
    await tester.pumpAndSettle();

    expect(harness.repository.calls, contains('setMode:light'));
    expect(harness.themeBloc.state.mode, AppearanceMode.light);
  });
}
