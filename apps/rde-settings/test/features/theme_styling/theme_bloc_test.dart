import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';

import 'theme_test_harness.dart';

void main() {
  test(
    'initial load publishes the catalog and previews the active scheme',
    () async {
      final repository = FakeThemeRepository();
      final bloc = buildThemeBloc(repository);

      final loaded = bloc.stream.firstWhere((state) => state.catalog != null);
      bloc.add(const ThemeInitEvent());
      final state = await loaded;

      expect(state.status, ThemeStatus.success);
      expect(state.catalog?.currentTheme, 'default');
      expect(state.themes.map((theme) => theme.name), ['default', 'ocean']);
      expect(state.previewScheme, RdeColorScheme.dark);
      expect(state.previewPalette?.theme, 'default');
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
    expect(state.colorScheme, RdeColorScheme.dark);

    await bloc.close();
    await repository.dispose();
  });

  test(
    'rejects deleting the active theme without calling the service',
    () async {
      final repository = FakeThemeRepository();
      final bloc = buildThemeBloc(repository);

      bloc.add(const ThemeInitEvent());
      await bloc.stream.firstWhere((state) => state.catalog != null);

      final failed = bloc.stream.firstWhere(
        (state) => state.errorMessage != null,
      );
      bloc.add(const DeleteThemeEvent('default'));
      final state = await failed;

      expect(state.errorMessage, contains('cannot be deleted'));
      expect(
        repository.calls.where((call) => call.startsWith('deleteTheme')),
        isEmpty,
      );

      await bloc.close();
      await repository.dispose();
    },
  );

  test('deleting an inactive theme removes it from the catalog', () async {
    final repository = FakeThemeRepository();
    final bloc = buildThemeBloc(repository);

    bloc.add(const ThemeInitEvent());
    await bloc.stream.firstWhere((state) => state.catalog != null);

    final deleted = bloc.stream.firstWhere(
      (state) => state.themes.every((theme) => theme.name != 'ocean'),
    );
    bloc.add(const DeleteThemeEvent('ocean'));
    final state = await deleted;

    expect(repository.calls, contains('deleteTheme:ocean'));
    expect(state.themes.map((theme) => theme.name), ['default']);

    await bloc.close();
    await repository.dispose();
  });

  test('changing the scheme updates the desktop scheme and preview', () async {
    final repository = FakeThemeRepository();
    final bloc = buildThemeBloc(repository);

    bloc.add(const ThemeInitEvent());
    await bloc.stream.firstWhere((state) => state.catalog != null);

    final switched = bloc.stream.firstWhere(
      (state) => state.colorScheme == RdeColorScheme.light,
    );
    bloc.add(const SetColorSchemeEvent(RdeColorScheme.light));
    final state = await switched;

    expect(repository.calls, contains('setColorScheme:light'));
    expect(state.previewScheme, RdeColorScheme.light);

    await bloc.close();
    await repository.dispose();
  });

  test('creating a theme installs and activates it', () async {
    final repository = FakeThemeRepository();
    final bloc = buildThemeBloc(repository);

    bloc.add(const ThemeInitEvent());
    await bloc.stream.firstWhere((state) => state.catalog != null);

    final created = bloc.stream.firstWhere(
      (state) => state.catalog?.currentTheme == 'forest',
    );
    bloc.add(const CreateThemeEvent(name: 'forest', sourceColor: '#2E7D32'));
    final state = await created;

    expect(
      repository.calls,
      containsAllInOrder(['createTheme:forest:#2E7D32', 'setTheme:forest']),
    );
    expect(state.activeTheme?.name, 'forest');

    await bloc.close();
    await repository.dispose();
  });

  test('a service property change reloads the catalog', () async {
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
