# D-Bus API Reference

This is the **public** API surface of RDE. Each service claims its own bus name on the **session bus** and exposes its interface directly — there is no central proxy. External tools (status bars, keyboard shortcut daemons, `rde-cli`) should talk to these interfaces directly.

For the *internal* daemon↔service protocol, see [`ipc-protocol.md`](ipc-protocol.md) instead.

## Services Reference

Each service documents its own D-Bus API contracts (methods, signals, and properties) locally within its package documentation:

- **org.rde.Brightness**: Detailed API is documented in [rde-brightness](/services/rde-brightness/README.md).
- **org.rde.Volume**: Detailed API is documented in [rde-volume](/services/rde-volume/README.md).
- **org.rde.Theme**: Detailed API is documented in [rde-theme README](/services/rde-theme/README.md).
- **org.rde.wifi**: Detailed API is documented in [rde-wifi README](/services/rde-wifi/README.md).
- **org.rde.Notification**: Detailed API is documented in [rde-notification README](/services/rde-notification/README.md).

### `org.rde.Brightness`

Owned by `rde-brightness` on the session bus at `/org/rde/Brightness`. The service is split into three layers: `domain/` parses `wlr-randr` output and performs sysfs/DDC-CI writes, `application/` routes commands and caches the active display, and `infrastructure/dbus.rs` exposes the interface below.

| Name | Type | Signature | Flag | Description |
| :--- | :--- | :--- | :--- | :--- |
| `IncreaseBrightness` | method | `u -> u` | – | Increase by `step` percentage points; returns the new percentage. |
| `DecreaseBrightness` | method | `u -> u` | – | Decrease by `step` percentage points; returns the new percentage. |
| `Brightness` | property | `u` | writable | Raw brightness on the target display's scale. |
| `BrightnessPercentage` | property | `u` | writable | Current brightness percentage. |
| `MaxBrightness` | property | `u` | read-only | Maximum raw value on the target display's scale. |
| `Version` | property | `s` | read-only | Service version. |
| `BrightnessChanged` | signal | `u` | – | Emitted after a successful change, carrying the new percentage. |

Changes are written to the internal backlight when the active connector is `eDP`, `LVDS`, or `DSI`, and to the external monitor over DDC/CI when it is `DP`, `HDMI`, or another external connector.

---

## Conventions

- All percentage values (`u percent`) are `0–100` unless a service explicitly documents otherwise (e.g. `rde-volume` allowing amplification above 100 if configured).
- Every mutating method emits a corresponding `*Changed` signal — clients should prefer subscribing to signals over polling `Get*` methods.
- `rde-brightness` writes sysfs and DDC/CI directly and relies on native device permissions instead of polkit: the service user must be able to write `/sys/class/backlight/*/brightness` (normally via the `video` group) and, for external monitors, access `/dev/i2c-*`.
- Interfaces are additive-only within a major version — new methods/signals may be added, but existing signatures will not change without a major version bump, documented in [`CHANGELOG.md`](/CHANGELOG.md).
