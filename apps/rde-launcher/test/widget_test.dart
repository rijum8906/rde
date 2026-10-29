import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';
import 'package:rde_launcher/features/app_search/domain/repositories/application_repository.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/find_applications.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/launch_application.dart';
import 'package:rde_launcher/features/app_search/domain/use_cases/load_applications.dart';
import 'package:rde_launcher/app.dart';

void main() {
  testWidgets('launcher filters installed applications as the user types', (
    tester,
  ) async {
    final repository = _FakeApplicationRepository([
      const DesktopApplication(
        id: 'org.example.browser.desktop',
        name: 'Web Browser',
        desktopFile: '/tmp/browser.desktop',
        description: 'Browse the internet',
      ),
      const DesktopApplication(
        id: 'org.example.terminal.desktop',
        name: 'Terminal',
        desktopFile: '/tmp/terminal.desktop',
        description: 'Command line',
      ),
    ]);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Web Browser'), findsOneWidget);
    expect(find.text('Terminal'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'terminal');
    await tester.pumpAndSettle();

    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Web Browser'), findsNothing);
  });

  testWidgets('category chips narrow the visible applications', (tester) async {
    final repository = _FakeApplicationRepository([
      const DesktopApplication(
        id: 'org.example.browser.desktop',
        name: 'Web Browser',
        desktopFile: '/tmp/browser.desktop',
        categories: ['Network', 'WebBrowser'],
      ),
      const DesktopApplication(
        id: 'org.example.terminal.desktop',
        name: 'Terminal',
        desktopFile: '/tmp/terminal.desktop',
        categories: ['System', 'TerminalEmulator'],
      ),
    ]);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    // The chip row precedes the results, so its label is the first match.
    await tester.tap(find.text('Internet').first);
    await tester.pumpAndSettle();

    expect(find.text('Web Browser'), findsOneWidget);
    expect(find.text('Terminal'), findsNothing);
  });

  testWidgets('Escape clears an active search, then closes the launcher', (
    tester,
  ) async {
    var closed = false;
    final repository = _FakeApplicationRepository([
      const DesktopApplication(
        id: 'org.example.browser.desktop',
        name: 'Web Browser',
        desktopFile: '/tmp/browser.desktop',
      ),
      const DesktopApplication(
        id: 'org.example.terminal.desktop',
        name: 'Terminal',
        desktopFile: '/tmp/terminal.desktop',
      ),
    ]);

    await tester.pumpWidget(_app(repository, onClose: () => closed = true));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'web');
    await tester.pumpAndSettle();

    // Step 1: With a query active, Escape restores the full list.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('Terminal'), findsOneWidget);

    // Step 2: With nothing to clear, Escape dismisses the launcher.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });

  testWidgets('arrow keys move the highlight and Enter launches it', (
    tester,
  ) async {
    final repository = _FakeApplicationRepository([
      const DesktopApplication(
        id: 'org.example.browser.desktop',
        name: 'Web Browser',
        desktopFile: '/tmp/browser.desktop',
      ),
      const DesktopApplication(
        id: 'org.example.terminal.desktop',
        name: 'Terminal',
        desktopFile: '/tmp/terminal.desktop',
      ),
    ]);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    // Focus the search field exactly as a user would before using arrows.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(repository.launched, ['Web Browser']);
  });

  test(
    'application search matches description and categories case-insensitively',
    () {
      const browser = DesktopApplication(
        id: 'browser.desktop',
        name: 'Web Browser',
        desktopFile: '/tmp/browser.desktop',
        description: 'Browse the internet',
        categories: ['Network', 'WebBrowser'],
      );

      expect(browser.matches('INTERNET'), isTrue);
      expect(browser.matches('network'), isTrue);
      expect(browser.matches('music'), isFalse);
    },
  );

  test('find use case sorts matching applications alphabetically', () {
    const useCase = FindApplications();
    const applications = [
      DesktopApplication(id: 'z', name: 'Zoom', desktopFile: '/z'),
      DesktopApplication(id: 'a', name: 'Calendar', desktopFile: '/a'),
    ];

    expect(useCase(applications, '').map((application) => application.name), [
      'Calendar',
      'Zoom',
    ]);
  });
}

/// Builds the launcher app around [repository] for widget tests.
Widget _app(ApplicationRepository repository, {VoidCallback? onClose}) {
  return RdeLauncherApp(
    onClose: onClose,
    initialTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    loadApplications: LoadApplications(repository),
    findApplications: const FindApplications(),
    launchApplication: LaunchApplication(repository),
  );
}

class _FakeApplicationRepository implements ApplicationRepository {
  _FakeApplicationRepository(this.applications);

  final List<DesktopApplication> applications;

  /// Names of the applications launch requests were made for.
  final List<String> launched = [];

  @override
  Future<List<DesktopApplication>> loadApplications() async => applications;

  @override
  Future<void> launch(DesktopApplication application) async {
    launched.add(application.name);
  }
}
