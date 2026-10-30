# RDE Shared Core

A shared Flutter foundation for RDE applications. It provides common error
models, reusable D-Bus and NetworkManager protocol APIs, theme service
contracts, theme parsing/cache/building and accent utilities, and a loading
indicator.

## Add to an RDE app

Use the local package dependency from the app's `pubspec.yaml`:

```yaml
dependencies:
  core:
    path: ../shared/core
```

Import the stable package entrypoints rather than copying implementations:

```dart
import 'package:core/core.dart';
import 'package:core/theme.dart';
```

`core.dart` is the full foundation entrypoint: it exports the common errors,
D-Bus clients, NetworkManager constants/models, theme APIs, and loading widget.
`theme.dart` is the focused theme entrypoint; it exposes theme entities, the
`org.rde.Theme` proxy, cache reader, Material theme builder, and seed helpers.

Apps should prefer these entrypoints over importing package internals. The
individual `core/...` and `core/theme/...` libraries remain available when a
consumer needs a narrower dependency surface.

## Scope

This package contains application-agnostic contracts and infrastructure.
Routes, navigation, feature-specific settings, and app-owned state management
belong in each application.
