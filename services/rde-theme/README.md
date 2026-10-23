# RDE Theme

RDE service for theme management. It stores a theme database, generates Material 3
palettes from a single source color per theme, and exposes the result on the session
bus as `org.rde.Theme`.

## Structure

- **`app/`**: Service lifecycle.
  - [`app/mod.rs`](src/app/mod.rs): global `App` singleton, D-Bus registration, signal handling, shutdown.
  - [`app/thread.rs`](src/app/thread.rs): daemon supervision task (connect, register, serve, deregister).
- **`handler/`**: Supervisor protocol handling.
  - [`handler/request.rs`](src/handler/request.rs): `HealthCheck`, `GetStatus`, `Shutdown`.
  - [`handler/response.rs`](src/handler/response.rs): `RegisterAck`.
- **`constants.rs`**: service name, D-Bus contract, storage layout, retry policy.
- **`paths.rs`**: XDG-compliant location of the theme database.
- **`theme_store/`**: persistence and state.
  - [`theme_store/mod.rs`](src/theme_store/mod.rs): registry + manifest state, CRUD, reconciliation.
  - [`theme_store/disk.rs`](src/theme_store/disk.rs): atomic TOML reads/writes, manifest scanning.
- **`domain/`**: theme models and color engine.
  - [`domain/theme.rs`](src/domain/theme.rs): `ThemeId`, `ColorScheme`, `ThemeManifest`, `Theme`.
  - [`domain/theme_config_file.rs`](src/domain/theme_config_file.rs): the `themes.toml` registry model.
  - [`domain/material/mod.rs`](src/domain/material/mod.rs): Material 3 palette generation.
  - [`domain/color.rs`](src/domain/color.rs): hex color parsing and formatting.
- **`backend/`**: palette resolution and toolkit output.
  - [`backend/mod.rs`](src/backend/mod.rs): `ThemeBackend` resolves manifests into palettes.
  - [`backend/qt/`](src/backend/qt/mod.rs): writes qt5ct/qt6ct and KDE color schemes.
- **`dbus/`**: `org.rde.Theme` interface at `/org/rde/Theme`.

## Theme Database

```
$XDG_DATA_HOME/rde/rde-theme/          # ~/.local/share/rde/rde-theme by default
├── themes.toml
└── themes/
    ├── default/
    │   └── theme.toml
    └── ocean/
        └── theme.toml
```

The service follows the XDG base directory specification: `$XDG_DATA_HOME` is used when
set, otherwise `~/.local/share`.

### `themes.toml` — registry

Session state only. It never stores palette values, so editing a theme's source color
cannot desynchronize the colors from the definition.

```toml
schema_version = 1
current_theme = "default"
color_scheme = "dark"
installed = ["default", "ocean"]
```

- `current_theme`: active theme, used for all palette lookups.
- `color_scheme`: `"light"` or `"dark"`, global to the desktop.
- `installed`: identifiers of installed themes. Treated as advisory: on startup the
  list is reconciled with the manifests found under `themes/`, so copying a theme
  directory in (or deleting one) is repaired automatically. A corrupt registry is moved
  to `themes.toml.invalid` and rebuilt.

### `themes/<name>/theme.toml` — manifest

The authoritative definition of one theme. `<name>` is the theme identifier and must
match the `name` field.

```toml
schema_version = 1
name = "ocean"
display_name = "Ocean"
description = "RDE theme generated from the source color #006A6A."
author = "Riju"
license = "MIT"
version = "1.0.0"
source_color = "#006A6A"
```

Only `source_color` contributes to the colors; every palette is regenerated from it,
which keeps light/dark variants, contrast levels, and future toolkit output consistent.

Theme identifiers may contain ASCII letters, digits, `-`, `_`, and `.`, must start with
an alphanumeric character, and are limited to 64 characters. That prevents path
traversal and hidden directories by construction.

## D-Bus API

Bus name `org.rde.Theme`, object path `/org/rde/Theme`, interface `org.rde.Theme`.

### Properties

| Property | Signature | Access | Description |
| :--- | :--- | :--- | :--- |
| `Version` | `s` | read | Service version (`CARGO_PKG_VERSION`) |
| `CurrentTheme` | `s` | read | Identifier of the active theme |
| `InstalledThemes` | `as` | read | Installed theme identifiers, sorted |
| `ColorScheme` | `s` | read/write | `light` or `dark` |
| `SourceColor` | `s` | read | Source color of the active theme, `#RRGGBB` |

Writing `ColorScheme` persists the preference, emits `ColorSchemeChanged` and the
standard `PropertiesChanged` signal.

### Methods

| Method | Signature | Description |
| :--- | :--- | :--- |
| `SetTheme` | `s → ()` | Activate an installed theme |
| `CreateTheme` | `ss → ()` | Create a theme from `(name, source_color)`; installed but not activated |
| `DeleteTheme` | `s → ()` | Delete an installed, non-active theme |
| `SetSourceColor` | `s → ()` | Re-seed the active theme and regenerate its palette |
| `ToggleColorScheme` | `() → s` | Switch light/dark and return the new scheme |
| `GetPalette` | `ss → a{ss}` | Palette role map for `(theme, scheme)` in `#RRGGBB` |
| `GetThemeInfo` | `s → a{ss}` | Manifest metadata for theme pickers |
| `Reload` | `() → ()` | Re-read the database after external changes |

Errors are mapped to standard FDO names: unknown themes report
`org.freedesktop.DBus.Error.FileNotFound`, existing themes
`org.freedesktop.DBus.Error.FileExists`, invalid names/colors/schemes
`org.freedesktop.DBus.Error.InvalidArgs`, and write failures
`org.freedesktop.DBus.Error.IOError`.

Every successful `SetTheme`, `SetSourceColor`, `ColorScheme` write,
`ToggleColorScheme`, and `Reload` also rewrites the [Qt color schemes](#qt-integration)
before its signals are emitted.

### Signals

| Signal | Signature | Emitted when |
| :--- | :--- | :--- |
| `ThemeChanged` | `ss` | The active theme changes (`theme`, `color_scheme`) |
| `ColorSchemeChanged` | `s` | The light/dark preference changes |
| `PaletteChanged` | `ss` | The active theme is re-seeded (`theme`, `source_color`) |
| `InstalledThemesChanged` | `as` | A theme is installed, removed, or reloaded |

### Examples

```bash
# List themes and the active one
gdbus call --session --dest org.rde.Theme --object-path /org/rde/Theme \
  --method org.freedesktop.DBus.Properties.GetAll org.rde.Theme

# Create a theme from a source color, then activate it
gdbus call --session --dest org.rde.Theme --object-path /org/rde/Theme \
  --method org.rde.Theme.CreateTheme ocean '#006A6A'
gdbus call --session --dest org.rde.Theme --object-path /org/rde/Theme \
  --method org.rde.Theme.SetTheme ocean

# Re-seed the active theme and read its dark palette
gdbus call --session --dest org.rde.Theme --object-path /org/rde/Theme \
  --method org.rde.Theme.SetSourceColor '#FF6200'
gdbus call --session --dest org.rde.Theme --object-path /org/rde/Theme \
  --method org.rde.Theme.GetPalette ocean dark
```

## Workflows

## Qt Integration

Qt and KDE applications are re-colored automatically. The service writes:

| File | Purpose |
| :--- | :--- |
| `$XDG_DATA_HOME/color-schemes/RdeM3.colors` | Standard KDE color scheme, discoverable in System Settings |
| `$XDG_CONFIG_HOME/kdeglobals` | Color groups used by KDE applications plus titlebar colors |
| `$XDG_CONFIG_HOME/qt5ct/colors/RdeM3.conf` | qt5ct color scheme |
| `$XDG_CONFIG_HOME/qt5ct/qt5ct.conf` | Activates the scheme (`custom_palette=true`, `color_scheme_path=…`) |
| `$XDG_CONFIG_HOME/qt6ct/colors/RdeM3.conf` | qt6ct color scheme |
| `$XDG_CONFIG_HOME/qt6ct/qt6ct.conf` | Activates the scheme for Qt 6 |

Defaults are `~/.local/share` and `~/.config`; the XDG variables are honored.

- **Material 3 mapping**: the palette is mapped onto Qt's `QPalette` roles
  (`Window`/`Base`/`Text` from surface roles, `Highlight` from `primary`, tooltips from
  `inverse_surface`, and so on) in `WindowText, Button, Light, …` serialization order.
  21 roles are written, which is the exact `QPalette::NColorRoles` count for Qt 5.12+
  and Qt 6, and works for qt6ct on Qt 6.6+, where `Accent` is derived from `Highlight`.
- **Plasma accent**: `kdeglobals [General] AccentColor` is pinned to the theme's
  primary color so Plasma 6 accent-colored widgets follow the theme.
- **Three color groups**: active and inactive share colors; disabled widgets keep the
  surfaces but neutralize text and links to outline tones.
- **Non-destructive merging**: only the appearance keys and color groups the service
  owns are changed. Comments, styles, fonts, icons, and unrelated keys in `kdeglobals`,
  `qt5ct.conf`, and `qt6ct.conf` are preserved.
- **Idempotent**: files are written atomically and only when their content changes, so
  Qt's configuration watcher is not woken up needlessly.
- **Best effort**: an unwritable Qt directory is logged as a warning and reported in the
  apply result; it never blocks theme changes or service startup.

Qt applications must use `QT_QPA_PLATFORMTHEME=qt5ct` (or `qt6ct`) for the palette to be
picked up; KDE applications read `kdeglobals` directly. Restart Qt applications that were
started before the first application to pick up the new palette. Qt 5.12+ and Qt 6 are
supported; older Qt 5 releases expect the pre-`PlaceholderText` color list and fall back
to their system palette.

Verify the generated files after a theme change:

```bash
cat ~/.config/qt5ct/colors/RdeM3.conf
cat ~/.local/share/color-schemes/RdeM3.colors
cat ~/.config/kdeglobals
```

## Workflows

### Theme creation

1. `CreateTheme(name, source_color)` validates the identifier and normalizes the color.
2. A manifest is written atomically to `themes/<name>/theme.toml`.
3. The registry gains the identifier and is written atomically.
4. `InstalledThemesChanged` and the `InstalledThemes` property change are emitted.
5. Palettes are derived on demand from the manifest, so no colors are persisted.

### Startup and recovery

1. Resolve the data directory and create it if needed.
2. Load `themes.toml`; quarantine it as `themes.toml.invalid` if unparsable.
3. Load every valid `themes/*/theme.toml`; invalid directories are skipped with a warning.
4. Seed the built-in `default` theme when no manifest exists.
5. Reconcile the installed list and active theme with the manifests, then persist the
   registry only when something changed.
6. Apply the active theme to Qt and KDE so a fresh session starts themed.

An active theme is always guaranteed once the service is up, and the active theme
cannot be deleted: switch to another theme first.

## Lifecycle

1. `App::global()` installs logging, opens the theme database, and creates the D-Bus object.
2. `App::run()` publishes `org.rde.Theme`, spawns the supervision task, and waits.
3. `SIGINT`, `SIGTERM`, or a supervisor `Shutdown` request triggers teardown.
4. `App::shutdown()` stops supervision and has a bounded wait for the socket task.

## Current Features

- Service lifecycle, logging, and daemon supervision
- Full theme database with self-healing registry and per-theme manifests
- Theme creation from a source color, activation, deletion, and re-seeding
- Material 3 palettes in light and dark schemes, exposed role by role over D-Bus
- Persistent light/dark preference
- Qt 5/6 and KDE color schemes applied at startup and on every theme change

## Upcoming Features

- GTK 3/4 `gtk.css` and `settings.ini` generation
- Freedesktop Portal `color-scheme` synchronization
- Typography and cursor configuration
