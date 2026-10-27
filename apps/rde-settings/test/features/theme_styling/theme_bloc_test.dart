import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/domain/entities/dynamic_seeds.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';

import 'theme_test_harness.dart';

void main() {
  test(
    'initial load publishes the catalog and previews the active appearance',
    () async {
      final repository = FakeThemeRepository();
      final bloc = buildThemeBloc(repository);

      final loaded = bloc.stream.firstWhere((state) => state.catalog != null);
      bloc.add(const ThemeInitEvent());
      final state = await loaded;

      expect(state.status, ThemeStatus.success);
      expect(state.catalog?.currentTheme, 'default');
      expect(state.themes.map((theme) => theme.name), [
        'default',
        'ocean',
        'rde-dynamic',
      ]);
      expect(state.previewMode, AppearanceMode.dark);
      expect(state.previewTheme?.themeId, 'default');
      expect(state.previewTheme?.variant, 'dark');
      expect(state.errorMessage, isNull);

      await bloc.close();
      await repository.dispose();
    },
  );

  test('selecting a theme activates it and reloads the catalog', () async {
    final repository = FakeThemeRepository();
    final bloc = buildThemeBloc(repository);

    bloc.add(const ThemeInitEvent());
    await bloc.stream.firstWhere((state) => state.catalog != null);

    final activated = bloc.stream.firstWhere(
      (state) => state.catalog?.currentTheme == 'ocean',
    );
    bloc.add(const SelectThemeEvent('ocean'));
    final state = await activated;

    expect(repository.calls, contains('setTheme:ocean'));
    expect(state.activeTheme?.displayName, 'Ocean');
    expect(state.mode, AppearanceMode.dark);

    await bloc.close();
    await repository.dispose();
  });

  test(
    'switching the appearance persists it and follows the payload',
    () async {
      final repository = FakeThemeRepository();
      final bloc = buildThemeBloc(repository);

      bloc.add(const ThemeInitEvent());
      await bloc.stream.firstWhere((state) => state.catalog != null);

      final switched = bloc.stream.firstWhere(
        (state) => state.mode == AppearanceMode.light && state.catalog != null,
      );
      bloc.add(const SetAppearanceEvent(AppearanceMode.light));
      final state = await switched;

      expect(repository.calls, contains('setMode:light'));
      expect(state.previewMode, AppearanceMode.light);
      expect(state.previewTheme?.variant, 'light');

      await bloc.close();
      await repository.dispose();
    },
  );

  test(
    'previewing the other appearance asks the service for a payload',
    () async {
      final repository = FakeThemeRepository();
      final bloc = buildThemeBloc(repository);

      bloc.add(const ThemeInitEvent());
      await bloc.stream.firstWhere((state) => state.catalog != null);

      final previewed = bloc.stream.firstWhere(
        (state) => state.previewTheme?.variant == 'light',
      );
      bloc.add(const SetPreviewModeEvent(AppearanceMode.light));
      final state = await previewed;

      expect(repository.calls, contains('preview:default:light'));
      expect(state.previewMode, AppearanceMode.light);
      // The desktop appearance itself did not change.
      expect(state.mode, AppearanceMode.dark);

      await bloc.close();
      await repository.dispose();
    },
  );

  test('changing one seed only repaints that family', () async {
    final repository = FakeThemeRepository();
    final bloc = buildThemeBloc(repository);

    bloc.add(const ThemeInitEvent());
    await bloc.stream.firstWhere((state) => state.catalog != null);

    final updated = bloc.stream.firstWhere(
      (state) => state.dynamicSeeds.tertiary == '#B90063',
    );
    bloc.add(const SetDynamicSeedEvent(DynamicSeedRole.tertiary, '#B90063'));
    final state = await updated;

    // The edited family carries the new color while every other family is
    // resent unchanged: the service requires a non-empty primary, so blanking
    // out the untouched seeds is no longer how the bloc asks it to keep them.
    final fallback = DynamicSeeds.fallback;
    expect(
      repository.calls,
      contains(
        'updateDynamicTheme:${fallback.primary}:${fallback.secondary}:'
        '#B90063:${fallback.error}',
      ),
    );
    expect(state.dynamicSeeds.primary, DynamicSeeds.fallback.primary);
    expect(state.dynamicSeeds.tertiary, '#B90063');

    await bloc.close();
    await repository.dispose();
  });

  test('extracting wallpaper seeds sends all four colors', () async {
    final repository = FakeThemeRepository()
      ..wallpaperSeeds = const DynamicSeeds(
        primary: '#123456',
        secondary: '#234567',
        tertiary: '#345678',
        error: '#456789',
      );
    final bloc = buildThemeBloc(repository);

    bloc.add(const ThemeInitEvent());
    await bloc.stream.firstWhere((state) => state.catalog != null);

    final updated = bloc.stream.firstWhere(
      (state) => state.dynamicSeeds.primary == '#123456',
    );
    bloc.add(const ExtractWallpaperSeedsEvent());
    final state = await updated;

    expect(repository.calls, contains('seedsFromWallpaper'));
    expect(
      repository.calls,
      contains('updateDynamicTheme:#123456:#234567:#345678:#456789'),
    );
    expect(state.dynamicSeeds.error, '#456789');

    await bloc.close();
    await repository.dispose();
  });

  test(
    'an unreadable wallpaper is reported without touching the service',
    () async {
      final repository = FakeThemeRepository()..failWallpaper = true;
      final bloc = buildThemeBloc(repository);

      bloc.add(const ThemeInitEvent());
      await bloc.stream.firstWhere((state) => state.catalog != null);

      final failed = bloc.stream.firstWhere(
        (state) => state.errorMessage != null,
      );
      bloc.add(const ExtractWallpaperSeedsEvent());
      final state = await failed;

      expect(state.errorMessage, 'The wallpaper could not be read.');
      expect(
        repository.calls.where((call) => call.startsWith('updateDynamicTheme')),
        isEmpty,
      );

      await bloc.close();
      await repository.dispose();
    },
  );

  test('a service change reloads the catalog', () async {
    final repository = FakeThemeRepository();
    final bloc = buildThemeBloc(repository);

    bloc.add(const ThemeInitEvent());
    await bloc.stream.firstWhere((state) => state.catalog != null);
    final loadsBefore = repository.loadCalls;

    // Simulate another RDE application switching the theme.
    repository.currentTheme = 'ocean';
    final reloaded = bloc.stream.firstWhere(
      (state) => state.catalog?.currentTheme == 'ocean',
    );
    repository.notifyChanged();
    await reloaded;

    expect(repository.loadCalls, greaterThan(loadsBefore));

    await bloc.close();
    await repository.dispose();
  });

  test(
    'load failures are surfaced without losing a previous catalog',
    () async {
      final repository = FakeThemeRepository();
      final bloc = buildThemeBloc(repository);

      bloc.add(const ThemeInitEvent());
      await bloc.stream.firstWhere((state) => state.catalog != null);

      repository.failLoad = true;
      final failed = bloc.stream.firstWhere(
        (state) => state.errorMessage != null,
      );
      repository.notifyChanged();
      final state = await failed;

      expect(state.status, ThemeStatus.success);
      expect(state.hasCatalog, isTrue);
      expect(state.errorMessage, 'The theme service is offline.');

      await bloc.close();
      await repository.dispose();
    },
  );
}
