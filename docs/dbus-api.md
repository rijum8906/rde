# D-Bus API Reference

This is the **public** API surface of RDE. Each service claims its own bus name on the **session bus** and exposes its interface directly — there is no central proxy. External tools (status bars, keyboard shortcut daemons, `rde-cli`) should talk to these interfaces directly.

For the *internal* daemon↔service protocol, see [`ipc-protocol.md`](ipc-protocol.md) instead.

## Table of Contents

- [org.rde.Brightness](dbus-api#org.rde.Brightness)
- [org.rde.Volume](dbus-api#`org.rde.Volume`)
- [org.rde.Theme](dbus-api#`org.rde.Theme`)
- [org.rde.Notification](dbus-api#`org.rde.Notification` (WIP))
- [Conventions](#conventions)

---

## org.rde.Brightness

- **Bus name**: `org.rde.Brightness`
- **Object path**: `/org/rde/Brightness`
- **Interface**: `org.rde.Brightness`

### Methods

| Method | Signature | Description |
| :--- | :--- | :--- |
| `SetBrightnessPercentage` | `(u percent) -> ()` | Sets brightness to an absolute percentage (0–100). Requires polkit authorization. |
| `SetBrightnessPercentage` | `() -> (u percent)` | Returns current brightness as a percentage. |
| `IncreaseBrightness` | `(u step) -> (u new_percent)` | Increases brightness by `step` percentage points, clamped to 100. |
| `DecreaseBrightness` | `(u step) -> (u new_percent)` | Decreases brightness by `step` percentage points, clamped to 0. |

### Signals

| Signal | Signature | Description |
| :--- | :--- | :--- |
| `BrightnessChanged` | `(u percent)` | Emitted whenever brightness changes, regardless of source (this API, another client, or a hotkey handled outside RDE). |

---

## `org.rde.Volume`

- **Bus name**: `org.rde.Volume`
- **Object path**: `/org/rde/Volume`
- **Interface**: `org.rde.Volume`

### Methods

| Method | Signature | Description |
| :--- | :--- | :--- |
| `SetVolume` | `(u percent) -> ()` | Sets output volume to an absolute percentage (0–100+, over-amplification allowed if configured). |
| `GetVolume` | `() -> (u percent)` | Returns current output volume. |
| `IncreaseVolume` | `(u step) -> (u new_percent)` | Raises volume by `step` percentage points. |
| `DecreaseVolume` | `(u step) -> (u new_percent)` | Lowers volume by `step` percentage points. |
| `SetMuted` | `(b muted) -> ()` | Mutes/unmutes output without changing the stored volume level. |
| `GetMuted` | `() -> (b muted)` | Returns current mute state. |

### Signals

| Signal | Signature | Description |
| :--- | :--- | :--- |
| `VolumeChanged` | `(u percent)` | Emitted on any volume change. |
| `MutedChanged` | `(b muted)` | Emitted on any mute-state change. |

---

## `org.rde.Theme`

- **Bus name**: `org.rde.Theme`
- **Object path**: `/org/rde/Theme`
- **Interface**: `org.rde.Theme`

### Methods

| Method | Signature | Description |
| :--- | :--- | :--- |
| `SetTheme` | `(s theme_name) -> ()` | Switches to a named theme (must exist in the theme store). |
| `GetTheme` | `() -> (s theme_name)` | Returns the currently active theme name. |
| `SetMode` | `(s mode) -> ()` | Sets mode to `"light"`, `"dark"`, or `"auto"`. |
| `GetMode` | `() -> (s mode)` | Returns the current mode. |
| `ListThemes` | `() -> (as theme_names)` | Returns all available theme names. |

### Signals

| Signal | Signature | Description |
| :--- | :--- | :--- |
| `ThemeChanged` | `(s theme_name)` | Emitted when the active theme changes. |
| `ModeChanged` | `(s mode)` | Emitted when light/dark/auto mode changes. |

---

## `org.rde.Notification` (WIP)

`rde-notification` implements the [freedesktop.org Desktop Notifications Specification](https://specifications.freedesktop.org/notification-spec/latest/) rather than a custom RDE interface, so existing tools (`notify-send`, libnotify-based apps) work unmodified.

- **Bus name**: `org.freedesktop.Notifications`
- **Object path**: `/org/freedesktop/Notifications`
- **Interface**: `org.freedesktop.Notifications`

| Method | Signature | Description |
| :--- | :--- | :--- |
| `Notify` | `(...) -> (u id)` | Standard spec method — see upstream spec for full argument list. |
| `CloseNotification` | `(u id) -> ()` | Closes a notification by ID. |
| `GetCapabilities` | `() -> (as)` | Returns supported capabilities. |
| `GetServerInformation` | `() -> (s name, s vendor, s version, s spec_version)` | Server identification. |

| Signal | Signature | Description |
| :--- | :--- | :--- |
| `NotificationClosed` | `(u id, u reason)` | Emitted when a notification closes. |
| `ActionInvoked` | `(u id, s action_key)` | Emitted when the user activates a notification action. |

> **Status**: WIP — method bodies are stubbed pending the notification rendering surface. Interface shape above matches the spec and is not expected to change.

---

## Conventions

- All percentage values (`u percent`) are `0–100` unless a service explicitly documents otherwise (e.g. `rde-volume` allowing amplification above 100 if configured).
- Every mutating method emits a corresponding `*Changed` signal — clients should prefer subscribing to signals over polling `Get*` methods.
- Methods that require elevated privileges (currently only `rde-brightness`'s sysfs writes) are gated by polkit; the policy files live in [`assets/polkit/`](../assets/polkit/).
- Interfaces are additive-only within a major version — new methods/signals may be added, but existing signatures will not change without a major version bump, documented in [`CHANGELOG.md`](../CHANGELOG.md).
