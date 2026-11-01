# RDE Brightness

RDE service for brightness control.

## Structure

The service is split into three layers so hardware rules stay testable and free
of D-Bus and async runtimes.

- **`domain/`**: display detection and hardware actuation (standard library,
  `thiserror`, and `tracing` only).
  - [`domain/display.rs`](src/domain/display.rs): parses `wlr-randr` output and
    classifies connectors as internal (`eDP`, `LVDS`, `DSI`) or external (`DP`,
    `HDMI`, and others).
  - [`domain/brightness.rs`](src/domain/brightness.rs): writes
    `/sys/class/backlight` values and drives external monitors over DDC/CI via
    `ddcutil`, resolving the I2C bus from `/sys/class/drm/card0-<output>/ddc`.
  - [`domain/error.rs`](src/domain/error.rs): `DomainError`.
- **`application/`**: command routing and in-memory state.
  - [`application/commands.rs`](src/application/commands.rs):
    `BrightnessCommand::{Set, Increase, Decrease}`.
  - [`application/service.rs`](src/application/service.rs): `BrightnessService`
    holds the active display and last known level, resolves the target display
    through the domain layer, and routes the write to the internal or external
    backend.
- **`infrastructure/`**: outside-world adapters.
  - [`infrastructure/dbus.rs`](src/infrastructure/dbus.rs): serves
    `org.rde.Brightness` at `/org/rde/Brightness` and translates calls into
    `BrightnessCommand`s.
  - [`infrastructure/ipc.rs`](src/infrastructure/ipc.rs): registers with
    `rde-daemon`, answers `HealthCheck`, `GetStatus`, and `Shutdown`, and
    deregisters on exit.

## Lifecycle

1. `main.rs` installs logging, builds `BrightnessService`, and starts supervision.
2. The application layer snapshots the active display; detection failures are
   logged and retried per request rather than aborting startup.
3. The D-Bus server publishes `org.rde.Brightness` and serves until shutdown.
4. `SIGINT`, `SIGTERM`, or a supervisor `Shutdown` request cancels the token.
5. Supervision is stopped with a bounded wait and the service deregisters.

## Hardware Access

The service writes brightness directly; there is no privileged helper and no
polkit action.

- **Internal panels:** the service user must be allowed to write
  `/sys/class/backlight/*/brightness`. Add the user to the `video` group and
  re-login so the session picks up the new membership. Distributions that ship
  restrictive stock permissions may also need a udev rule that sets the
  backlight file's group to `video`.
- **External monitors:** `ddcutil` talks to `/dev/i2c-*`, so the service user
  needs access to the I2C devices as well (commonly the `i2c` group or a udev
  rule).

No `pkexec`, polkit policy, or root helper binary is used.

## DBus Interface

| Name | Type | Signature | Flag | Description
| :--- | :--- |  :--- | :--- | :--- |
| IncreaseBrightness | method | u -> u | - | Increases brightness by `step` percentage points and returns the new percentage. |
| DecreaseBrightness | method | u -> u | - | Decreases brightness by `step` percentage points and returns the new percentage. |
| Brightness | property | u | writable | Current raw brightness value on the target display's scale. |
| BrightnessPercentage | property | u | writable | Current brightness percentage. |
| MaxBrightness | property | u | read-only | Maximum raw brightness value on the target display's scale. |
| Version | property | s | read-only | Version of the service. |
| BrightnessChanged | signal | u | - | Emitted when brightness changes. |
