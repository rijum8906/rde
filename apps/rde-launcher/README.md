# RDE Launcher

A centered Linux application launcher built with Flutter. It discovers visible
XDG `.desktop` applications, filters them by name, description, desktop ID, or
category, and launches the selected app through GTK's `gtk-launch` command.

## Structure

`lib/features/app_search` follows the Settings app's feature boundaries:

- `data`: XDG desktop-entry discovery and GTK launching
- `domain`: application entity, repository contract, and use cases
- `presentation`: search state, controller, and launcher UI

The launcher reads the desktop theme cache and follows subsequent `org.rde.Theme`
updates through the shared `apps/shared/core` package.

## Run

From this directory, run `flutter pub get` and `flutter run -d linux`.
Keyboard controls: type to search, use ↑/↓ to select, Enter to launch, and
Escape to clear the search.
