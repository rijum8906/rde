import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/get_dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/save_dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/update_dynamic_theme.dart';

import '../theme_styling/theme_test_harness.dart';

void main() {
  test(
    'picking a seed color re-seeds and activates the desktop theme',
    () async {
      final themes = FakeThemeRepository();
      final bloc = buildDashboardBloc(themes);

      final picked = bloc.stream.firstWhere(
        (state) => state.accentColor == const Color(0xFF0061A4),
      );
      bloc.add(const ChangeAccentColorEvent(Color(0xFF0061A4)));
      await picked;

      // The accent is sent as the primary seed only, and the dynamic theme is
      // activated afterwards, so the desktop renders the regenerated palette
      // instead of keeping the previously active theme.
      await _waitFor(() => themes.calls.length >= 2);
      expect(themes.calls, [
        'updateDynamicTheme:#0061A4:::',
        'setTheme:rde-dynamic',
      ]);
      expect(themes.dynamicSeeds.primary, '#0061A4');
      expect(themes.currentTheme, 'rde-dynamic');

      await bloc.close();
      await themes.dispose();
    },
  );
}

/// Builds a dashboard bloc whose personalization controls reach [themes].
DashboardBloc buildDashboardBloc(FakeThemeRepository themes) {
  final dashboard = DashboardRepositoryImpl();
  return DashboardBloc(
    getSettingsUseCase: GetDashboardSettingsUseCase(dashboard),
    saveSettingsUseCase: SaveDashboardSettingsUseCase(dashboard),
    updateDynamicTheme: UpdateDynamicThemeUseCase(themes),
    setTheme: SetThemeUseCase(themes),
  );
}

/// Drains the event queue until [condition] holds.
Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 50 && !condition(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue, reason: 'the theme service was not called');
}
