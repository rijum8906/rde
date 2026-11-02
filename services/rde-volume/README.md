# RDE Volume Service (`rde-volume`)

An independent, decoupled system microservice for managing master audio volume and playback mute state within the Riju Desktop Environment (RDE). It interacts directly with the Linux ALSA sound subsystem and registers with the RDE supervisor daemon over a Unix Domain Socket (UDS) IPC channel.

---

## 🛠️ Architecture Overview

The crate is structured as follows:
- **`app/`**: Service lifecycle control, handling startup, event loops, and graceful shutdown.
  - [`app/mod.rs`](src/app/mod.rs): global `App` singleton, D-Bus registration, signal handling, and shutdown.
  - [`app/thread.rs`](src/app/thread.rs): daemon supervision task (connect, register, serve, deregister).
- **`handler/`**: Supervision protocol handling.
  - [`handler/request.rs`](src/handler/request.rs): `HealthCheck`, `GetStatus`, `Shutdown`.
  - [`handler/response.rs`](src/handler/response.rs): `RegisterAck`.
- **`constants.rs`**: service name, D-Bus contract, and retry policy.
- **`backend/`**: Audio business logic engine and calculation rules.
  - [`backend/mod.rs`](src/backend/mod.rs): Master volume clamping, incremental step calculation, and mute toggling.
  - [`backend/tests.rs`](src/backend/tests.rs): Comprehensive unit tests covering boundary limits and error propagation.
- **`dbus/`**: D-Bus presentation layer.
  - [`dbus/iface.rs`](src/dbus/iface.rs): Public session D-Bus interface exposing properties, methods, and signals.
- **`domain/`**: Pure domain structs, audio models, and limits.
  - [`domain/models.rs`](src/domain/models.rs): State snapshots (`VolumeState`) and volume boundaries.
- **`infra/`**: Hardware driver integrations and test mocks.
  - [`infra/alsa.rs`](src/infra/alsa.rs): Native Linux ALSA mixer controller with automatic fallback discovery.
  - [`infra/mock.rs`](src/infra/mock.rs): In-memory simulated audio hardware for CI/virtualized environments.
---

## 📡 D-Bus API Reference

The service publishes its interface on the **session bus**:
- **Service Name**: `org.rde.Volume`
- **Object Path**: `/org/rde/Volume`
- **Interface**: `org.rde.Volume`

### Properties

| Property Name | Type | Access | Description |
|---|---|---|---|
| `Version` | `String` | Read-only | Service package version. |
| `Volume` | `uint8` | Read-write | Current master volume percentage (`0`–`100`). |
| `Muted` | `boolean` | Read-write | Whether audio playback is currently muted. |
| `MicrophoneVolume` | `uint8` | Read-write | Current microphone capture percentage (`0`–`100`). |
| `MicrophoneMuted` | `boolean` | Read-write | Whether microphone capture is currently muted. |

Set any writable property through `org.freedesktop.DBus.Properties.Set`.
`zbus` emits `PropertiesChanged` on its own, so clients never need a custom
signal. The `0`–`100` range is part of the contract rather than a property;
the service clamps out-of-range writes.

### Methods

Every method below changes a property outside of its setter, so the service
republishes that property through `PropertiesChanged`.

#### `IncreaseVolumeBy`
- **Signature**: `IncreaseVolumeBy(step: uint8) -> ()`
- **Description**: Increases master volume by `step` percentage points.

#### `DecreaseVolumeBy`
- **Signature**: `DecreaseVolumeBy(step: uint8) -> ()`
- **Description**: Decreases master volume by `step` percentage points.

#### `ToggleMute`
- **Signature**: `ToggleMute() -> ()`
- **Description**: Inverts the current playback mute state.

### Signals

None of the service's own. Clients watch `PropertiesChanged` on
`org.freedesktop.DBus.Properties`, which carries `Volume`, `Muted`,
`MicrophoneVolume`, and `MicrophoneMuted`.

---

## 📦 Domain Models

All core data structures, state snapshots, and configuration limits are defined in:
- [domain/models.rs](src/domain/models.rs)

---

## ⚙️ Development Commands

To run formatting, lints, and unit tests:
```bash
# Format codebase
cargo fmt --all

# Run strict clippy lints
cargo clippy --package rde-volume --all-targets -- -D warnings

# Execute unit tests
cargo test --package rde-volume
```
