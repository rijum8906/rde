import 'package:flutter_test/flutter_test.dart';
import 'package:core/theme.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';

import 'theme_test_harness.dart';

void main() {
  test(
    'initial load publishes the theme state and previews the active appearance',
    () async {
      final repository = FakeThemeRepository();
      final bloc = buildThemeBloc(repository);

      final loaded = bloc.stream.firstWhere((state) => state.hasData);
      bloc.add(const ThemeInitEvent());
      final state = await loaded;

      expect(state.status, ThemeStatus.success);
      expect(state.currentTheme, 'default');
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

  test(
    'selecting a theme activates it and reads only the new payload',
    () async {
      final repository = FakeThemeRepository();
      final bloc = buildThemeBloc(repository);

      bloc.add(const ThemeInitEvent());
      await bloc.stream.firstWhere((state) => state.hasData);
      final themeLoadsBefore = repository.themeLoads;

      final activated = bloc.stream.firstWhere(
        (state) => state.currentTheme == 'ocean',
      );
      bloc.add(const SelectThemeEvent('ocean'));
      final state = await activated;

      expect(repository.calls, contains('setTheme:ocean'));
      expect(state.activeTheme?.displayName, 'Ocean');
      expect(state.mode, AppearanceMode.dark);
      // The registry did not change, so the manifests were not read again.
      expect(repository.themeLoads, themeLoadsBefore);

      await bloc.close();
      await repository.dispose();
    },
  );

  test(
    'switching the appearance commits it without reading the payload back',
    () async {
      final repository = FakeThemeRepository();
      final bloc = buildThemeBloc(repository);

      bloc.add(const ThemeInitEvent());
      await bloc.stream.firstWhere((state) => state.hasData);
      final resolvedReadsBefore = repository.resolvedReads;

      final switched = bloc.stream.firstWhere(
        (state) => state.mode == AppearanceMode.light,
      );
      bloc.add(const SetAppearanceEvent(AppearanceMode.light));
      final state = await switched;

      expect(repository.calls, contains('setMode:light'));
      expect(state.previewMode, AppearanceMode.light);
      // The successful write is the new appearance: the payload is not read
      // again, it follows with the service notification instead.
      expect(repository.resolvedReads, resolvedReadsBefore);

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
      await bloc.stream.firstWhere((state) => state.hasData);

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

  test('picking an accent derives and sends all four seeds', () async {
    final repository = FakeThemeRepository();
    final bloc = buildThemeBloc(repository);

    bloc.add(const ThemeInitEvent());
    await bloc.stream.firstWhere((state) => state.hasData);

    final expected = seedsFromAccent('#B90063');
    final updated = bloc.stream.firstWhere(
      (state) => state.dynamicSeeds == expected,
    );
    bloc.add(const SetDynamicAccentEvent('#B90063'));
    final state = await updated;

    // The accent is the primary seed and every family is newly derived, so the
    // service receives a complete four-color update.
    expect(expected.primary, '#B90063');
    expect(
      repository.calls,
      contains(
        'updateDynamicTheme:${expected.primary}:${expected.secondary}:'
        '${expected.tertiary}:${expected.error}',
      ),
    );
    expect(state.dynamicSeeds, expected);

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
    await bloc.stream.firstWhere((state) => state.hasData);

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
      await bloc.stream.firstWhere((state) => state.hasData);

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

  test(
    'a published payload refreshes the colors without reloading the manifests',
    () async {
      final repository = FakeThemeRepository();
      final bloc = buildThemeBloc(repository);

      bloc.add(const ThemeInitEvent());
      await bloc.stream.firstWhere((state) => state.hasData);
      final themeLoadsBefore = repository.themeLoads;
      final resolvedReadsBefore = repository.resolvedReads;

      // Simulate another RDE application switching the theme.
      repository.currentTheme = 'ocean';
      final reloaded = bloc.stream.firstWhere(
        (state) => state.currentTheme == 'ocean',
      );
      repository.notifyChanged();
      final state = await reloaded;

      expect(state.resolved?.themeId, 'ocean');
      // The notification already carried the payload and the registry list.
      expect(repository.resolvedReads, resolvedReadsBefore);
      expect(repository.themeLoads, themeLoadsBefore);

      await bloc.close();
      await repository.dispose();
    },
  );

  test('a registry change reloads only the manifests', () async {
    final repository = FakeThemeRepository();
    final bloc = buildThemeBloc(repository);

    bloc.add(const ThemeInitEvent());
    await bloc.stream.firstWhere((state) => state.hasData);

    // Simulate a theme being installed by another application.
    repository.manifests['forest'] = const ThemeManifest(
      schemaVersion: 1,
      name: 'forest',
      displayName: 'Forest',
      description: 'forest theme',
      version: '1.0.0',
      defaultVariant: 'dark',
      variants: [
        ThemeVariant(
          id: 'dark',
          mode: AppearanceMode.dark,
          contrast: ContrastLevel.normal,
          filePath: 'dark.json',
        ),
      ],
    );
    final installSeen = bloc.stream.firstWhere(
      (state) => state.themes.any((theme) => theme.name == 'forest'),
    );
    repository.notifyChanged();
    await installSeen;

    await bloc.close();
    await repository.dispose();
  });

  test('refresh failures are surfaced without losing the previous state', () async {
    final repository = FakeThemeRepository();
    final bloc = buildThemeBloc(repository);

    bloc.add(const ThemeInitEvent());
    await bloc.stream.firstWhere((state) => state.hasData);

    // A registry change is the only refresh that reads the manifests, so it is
    // the one that can fail while the page keeps rendering old data.
    repository.manifests['forest'] = const ThemeManifest(
      schemaVersion: 1,
      name: 'forest',
      displayName: 'Forest',
      description: 'forest theme',
      version: '1.0.0',
      defaultVariant: 'dark',
      variants: [
        ThemeVariant(
          id: 'dark',
          mode: AppearanceMode.dark,
          contrast: ContrastLevel.normal,
          filePath: 'dark.json',
        ),
      ],
    );
    repository.failLoad = true;
    final failed = bloc.stream.firstWhere(
      (state) => state.errorMessage != null,
    );
    repository.notifyChanged();
    final state = await failed;

    expect(state.status, ThemeStatus.success);
    expect(state.hasData, isTrue);
    expect(state.errorMessage, 'The theme service is offline.');

    await bloc.close();
    await repository.dispose();
  });
}
