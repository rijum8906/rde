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
- **`domain/`**: pure theme models. No toolkit or color-engine types.
  - [`domain/theme.rs`](src/domain/theme.rs): `ThemeId`, `ColorScheme`, `ThemeManifest`, `Theme`.
  - [`domain/palette.rs`](src/domain/palette.rs): semantic color roles (`primary`, `surface`, ...).
  - [`domain/theme_config.rs`](src/domain/theme_config.rs): the `themes.toml` registry model.
  - [`domain/color.rs`](src/domain/color.rs): hex color parsing and formatting.
- **`backend/`**: palette engines and toolkit output.
  - [`backend/mod.rs`](src/backend/mod.rs): `ThemeBackend` trait that resolves manifests into palettes.
  - [`backend/material/`](src/backend/material/mod.rs): Material 3 seed and scheme computation.
  - [`backend/kde/`](src/backend/kde/mod.rs): writes `kdeglobals` and the Plasma color scheme.
  - [`backend/qt/`](src/backend/qt/mod.rs): writes qt5ct/qt6ct palettes and tool configs.
  - [`backend/gtk/`](src/backend/gtk/mod.rs): renders GTK CSS `@define-color` overrides.
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

### Published theme cache

Before emitting `ThemeChanged`, the service atomically writes the resolved payload to
`$XDG_DATA_HOME/rde/rde-theme/default_theme.json` (`~/.local/share/rde/rde-theme/default_theme.json`
by default). Applications read this file at startup so the first frame already renders the
desktop theme; after a `ThemeChanged` signal they reload the authoritative payload with
`GetResolvedTheme`.

### Dynamic theme seeds

The built-in `rde-dynamic` theme renders four role families, each from its own seed
color. The seeds live in the user's settings file:

```toml
[dynamic]
primary = "#6750a4"
secondary = "#006a6a"
tertiary = "#b52700"
error = "#ba1a1a"
```

Primary also drives the neutral surfaces, outlines, and inverse roles; secondary,
tertiary, and error each drive their own tonal palette. Changing one seed only repaints
that family.

The service never reads wallpapers or any other image. Desktop environments, shells, and
settings apps are responsible for extracting seeds (for example from the current KDE
wallpaper) and sending them with `UpdateDynamicTheme`.

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
| `Version` | `u` | read | Interface contract version |
| `ActiveTheme` | `s` | read | Identifier of the active theme, empty for the built-in dynamic theme |
| `Mode` | `s` | read | `light` or `dark` |
| `AvailableThemes` | `as` | read | Installed theme identifiers |
| `Generation` | `u` | read | Publication generation of the resolved payload |

The dynamic seeds are write-only through `UpdateDynamicTheme`; they are not mirrored as
properties.

### Methods

| Method | Signature | Description |
| :--- | :--- | :--- |
| `GetResolvedTheme` | `() → (ussu<roles>(ss)(ddddd)(uuuss))` | Payload the desktop currently renders |
| `GetThemeManifest` | `s → (ussssssa{s(uusss)}s)` | Author manifest of one theme |
| `ListThemes` | `() → as` | Installed theme identifiers |
| `SetActiveTheme` | `s → ()` | Activate an installed theme (`rde-dynamic` for the built-in one) |
| `SetMode` | `s → ()` | Persist `light` or `dark` and republish |
| `UpdateDynamicTheme` | `ssss → ()` | Store `(primary, secondary, tertiary, error)` seeds and republish the dynamic theme; `primary` is required, an empty optional seed keeps the stored color |
| `Reload` | `() → ()` | Re-read manifests, variant files, and settings |
| `Preview` | `sss → s` | Resolve a theme for an appearance without committing it |

Errors are mapped to standard FDO names: unknown themes and malformed payloads report
`org.freedesktop.DBus.Error.InvalidArgs`, and persistence or resolution failures report
`org.freedesktop.DBus.Error.Failed`.

Every successful mutation rewrites the [Qt color schemes](#qt-integration) before its
signals are emitted.

### Signals

| Signal | Signature | Emitted when |
| :--- | :--- | :--- |
| `ThemeChanged` | `su` | A new payload is durable on disk (`resolved_json`, `generation`) |
| `ThemeListChanged` | `as` | An installed theme is added or removed |
| `Reloaded` | `()` | A reload completed |

### Examples

```bash
# Read the current state and seeds
gdbus call --session --dest org.rde.Theme --object-path /org/rde/Theme \
  --method org.freedesktop.DBus.Properties.GetAll org.rde.Theme

# Re-seed the dynamic theme from four colors and activate it
gdbus call --session --dest org.rde.Theme --object-path /org/rde/Theme \
  --method org.rde.Theme.UpdateDynamicTheme '#6750A4' '#006A6A' '#B52700' '#BA1A1A'
gdbus call --session --dest org.rde.Theme --object-path /org/rde/Theme \
  --method org.rde.Theme.SetActiveTheme rde-dynamic

# Change only the primary seed
gdbus call --session --dest org.rde.Theme --object-path /org/rde/Theme \
  --method org.rde.Theme.UpdateDynamicTheme '#FF6200' '' '' ''
```

## Workflows

## Qt Integration

Qt and KDE applications are re-colored automatically. The service writes:

| File | Purpose |
| :--- | :--- |
| `$XDG_DATA_HOME/color-schemes/<theme>-<variant>-v<generation>.colors` | Plasma color scheme, applied with `plasma-apply-colorscheme` |
| `$XDG_CONFIG_HOME/kdeglobals` | Color groups read by KDE applications, `[General] AccentColor` for Plasma accents |
| `$XDG_CONFIG_HOME/qt5ct/colors/<theme>-<variant>-v<generation>.conf` | qt5ct palette, written only when qt5ct is installed |
| `$XDG_CONFIG_HOME/qt5ct/qt5ct.conf` | qt5ct selection (`custom_palette`, `color_scheme_path`), merged |
| `$XDG_CONFIG_HOME/qt6ct/…` | Same pair for qt6ct |

`kdeglobals` and the qt5ct/qt6ct configs are merged, not replaced: only the keys
the service owns are rewritten, so styles, fonts, icons, and unrelated keys
survive every theme change. The generated scheme and palette names carry the
publication generation, so a regenerated palette is a new file instead of an
overwrite the desktop cannot notice.

Defaults are `~/.local/share` and `~/.config`; the XDG variables are honored.

- **Material 3 mapping**: the palette is mapped onto Qt's `QPalette` roles in its
  `WindowText, Button, Light, …` serialization order, giving each accent family a
  distinct job: `Button`/`ButtonText` from `secondary_container`, `Highlight`/
  `HighlightedText` from `primary_container`, `Link`/`Accent` from `primary`,
  `LinkVisited` from `tertiary`, and tooltips from `inverse_surface`. Surfaces stay
  neutral, with `Base` from `surface_container_low` and `AlternateBase` one tier
  above it so alternating rows remain visible. 22 values are written per group
  (including the unused `NoRole` slot and the Qt 6.6 `Accent` role) so every role
  index lines up; Qt 5 ignores the trailing `Accent` value.
- **Plasma accent**: `kdeglobals [General] AccentColor` is pinned to the theme's
  primary color so Plasma 6 accent-colored widgets follow the theme.
- **Three color groups**: active and inactive share colors; disabled widgets keep the
  surfaces but neutralize text and links to outline tones.
- **Non-destructive merging**: only the appearance keys and color groups the service
  owns are changed. Comments, styles, fonts, icons, and unrelated keys in `kdeglobals`
  and the qt5ct/qt6ct configs are preserved.
- **Idempotent**: files are written atomically and only when their content changes, so
  Qt's configuration watcher is not woken up needlessly.
- **Best effort**: an unwritable Qt directory is logged as a warning and reported in the
  apply result; it never blocks theme changes or service startup.

qt5ct/qt6ct are only written when their platform theme is detected or their config
directory already exists. Qt applications must use `QT_QPA_PLATFORMTHEME=qt5ct` (or
`qt6ct`) for the palette to be picked up; KDE applications read `kdeglobals` directly.
Restart Qt applications that were started before the first application to pick up the
new palette; KDE updates apply live through `plasma-apply-colorscheme`.

Verify the generated files after a theme change:

```bash
cat ~/.local/share/color-schemes/*-v*.colors
cat ~/.config/kdeglobals
ls ~/.config/qt5ct/colors ~/.config/qt6ct/colors
```

## Workflows

### Dynamic theme re-seeding

1. `UpdateDynamicTheme(primary, secondary, tertiary, error)` requires a primary seed and
   validates every provided seed before anything is written.
2. `settings.toml` is rewritten atomically; an empty secondary, tertiary, or error
   argument keeps the stored seed.
3. When `rde-dynamic` is active, all six mode/contrast variants are regenerated and the
   published payload is replaced.
4. `ThemeChanged` is emitted only after the new payload is durable on disk.

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
- Theme activation and a dynamic theme seeded from primary, secondary, tertiary, and
  error colors
- Material 3 palettes in light and dark schemes, exposed role by role over D-Bus
- Persistent light/dark preference
- Qt 5/6 and KDE color schemes applied at startup and on every theme change

## Upcoming Features

- GTK 3/4 `gtk.css` and `settings.ini` generation
- Freedesktop Portal `color-scheme` synchronization
- Typography and cursor configuration
