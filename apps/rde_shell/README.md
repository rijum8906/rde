# RDE Shell (`rde_shell`)

The RDE desktop shell: a Wayland layer-shell surface that draws the top panel
and the top-centre notification overlay over the desktop.

## Layout

The shell owns one top-anchored layer surface with a 40 px exclusive zone. The
surface grows downwards only while notifications are visible, so maximised
windows are never displaced, and the transparent area below the panel passes
pointer input through to the desktop.

```
┌──────────────────────────────────────────────┐
│  panel: RDE mark · clock                     │  40 px, exclusive zone
├──────────────────────────────────────────────┤
│             ┌────────────────────┐           │  notification lane,
│             │ icon  title    ✕   │           │  grows/shrinks with
│             │       message      │           │  the queue
│             └────────────────────┘           │
└──────────────────────────────────────────────┘
```

## Architecture

```
lib/
├── app.dart                       MaterialApp, theme, notification wiring
├── main.dart                      layer-shell bootstrap + runApp
├── core/
│   ├── bootstrap/                 Wayland layer-shell setup
│   ├── constants/                 shared shell geometry
│   ├── shell/shell_surface.dart   resizes the surface + input region
│   └── theme/                     Material 3 Expressive theme and motion
└── features/
    └── notifications/
        ├── domain/                ShellNotification, severity, repository
        ├── data/                  demo notification feed
        └── presentation/          cubit, queue state, card, lane host
```

Notifications follow the same `domain` / `data` / `presentation` split used by
`rde-settings`. The presentation layer only depends on
`NotificationRepository`, so a D-Bus source can replace the demo feed without
touching the UI.

## Notification behaviour

- **Queue** – up to three cards are visible, newest first. Extra notifications
  wait and take a slot when a card finishes its exit animation.
- **Entrance** – cards spring down from behind the panel with a slight
  overshoot; the icon badge scales in on a short delay.
- **Exit** – a timeout, tap, upward drag, or the hover close button starts a
  quick fade/slide out; the slot is released only after the animation ends.
- **Life bar** – a tonal bar under the card mirrors the remaining time.
  Hovering pauses it, so cards never disappear while being read.
- **Depth** – cards behind the newest one scale down and dim, and reflow with
  `AnimatedPositioned` when the stack changes.
- **Accessibility** – the card is a live region and reduced-motion settings
  skip the spring and shorten the exit.

Severities (`info`, `success`, `warning`, `error`, `network`) map to expressive
icons and tones; the demo feed includes Wi-Fi connect/disconnect examples.

## Running

```bash
flutter pub get
flutter run -d linux
```

The demo feed is on by default. Disable it with:

```bash
flutter run -d linux --dart-define=RDE_SHELL_DEMO=false
```

or inject a `NotificationRepository` into `RdeShellApp`.

## Verification

```bash
flutter analyze
flutter test
```

## Limitations

- `DemoNotificationRepository` is a placeholder until `org.rde.Notification`
  (or Wi-Fi events from `org.rde.Wifi`) is exposed over D-Bus.
- While the lane is expanded, its full-width band accepts pointer input so the
  centred card can be hovered and dismissed. Space either side of the card in
  that band does not pass clicks through.
- The shell requires a compositor supporting `zwlr_layer_shell_v1`.
