# RDE Shell (`rde_shell`)

The RDE desktop shell: a single top panel drawn on a Wayland layer surface.

## Layout

The shell owns one top-anchored layer surface, `panelHeight` pixels tall, and
reserves an exclusive zone of the same height so maximised windows stop at the
panel's bottom edge.

```
┌──────────────────────────────────────────────┐
│ mark  RDE · Desktop          ⌁ ⌂ ▮  12:00    │  40 px, exclusive zone
└──────────────────────────────────────────────┘
```

There is no dynamic growth: the surface is always exactly as tall as the panel.

## Structure

```
lib/
├── main.dart                       layer-shell bootstrap + runApp
├── app.dart                        MaterialApp, theme, panel host
├── core/
│   ├── bootstrap/                  Wayland layer-shell setup
│   ├── constants/                  panel geometry
│   └── theme/                      Material 3 dark theme
└── panel/shell_panel.dart          the top bar itself
```

## Running

```bash
flutter pub get
flutter run -d linux
```

The shell is a panel on compositors implementing `zwlr_layer_shell_v1` (Sway,
SwayFX, Wayfire, Hyprland, River, niri, labwc, KWin). Without it the window
falls back to a normal toplevel and still renders the panel.

## Verification

```bash
flutter analyze
flutter test
```
