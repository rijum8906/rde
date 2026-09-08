# RDE Volume Service (`rde-volume`)

An independent, decoupled system microservice for managing master audio volume and playback mute state within the Riju Desktop Environment (RDE). It interacts directly with the Linux ALSA sound subsystem and registers with the RDE supervisor daemon over a Unix Domain Socket (UDS) IPC channel.

---

## 🛠️ Architecture Overview

The crate is structured as follows:
- **`app/`**: Core daemon lifecycle control, handling startup, event loops, and graceful shutdown sequence.
  - [`app/mod.rs`](src/app/mod.rs): Application singleton, logging initialization, and status tracking.
  - [`app/run.rs`](src/app/run.rs): Session D-Bus registration, IPC connector spawning, and signal monitoring.
  - [`app/shutdown.rs`](src/app/shutdown.rs): Clean resource teardown and supervisor disconnection.
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
- **`ipc/`**: Supervision protocol handler for communicating with `rde-daemon`.
  - [`ipc/handler.rs`](src/ipc/handler.rs): IPC socket connector, retry loops, and message dispatch.
  - [`ipc/daemon_request.rs`](src/ipc/daemon_request.rs): Handlers for `HealthCheck`, `GetStatus`, and `Shutdown`.
  - [`ipc/daemon_response.rs`](src/ipc/daemon_response.rs): Handlers for `RegisterAck`.

---

## 📡 D-Bus API Reference

The service publishes its interface on the **session bus**:
- **Service Name**: `org.rde.Volume`
- **Object Path**: `/org/rde/Volume`
- **Interface**: `org.rde.Volume`

### Properties

| Property Name | Type | Access | Description |
|---|---|---|---|
| `Volume` | `uint8` | Read-write | Current master volume percentage (`0`–`100`). Setting emits `VolumeChanged`. |
| `Muted` | `boolean` | Read-write | Whether audio playback is currently muted. Setting emits `MuteChanged`. |
| `Step` | `uint8` | Read-write | Default step size percentage used for volume increments/decrements (typically `5`). |
| `MinVolume` | `uint8` | Read-only | Minimum supported volume percentage (`0`). |
| `MaxVolume` | `uint8` | Read-only | Maximum supported volume percentage (`100`). |
| `Version` | `String` | Read-only | Returns the service package version. |

### Methods

#### `SetVolume`
- **Signature**: `SetVolume(volume: uint8) -> ()`
- **Description**: Sets absolute master volume percentage (`0`–`100`). Emits a `VolumeChanged` signal.

#### `IncreaseVolume`
- **Signature**: `IncreaseVolume() -> ()`
- **Description**: Increases master volume by the configured default step size. Emits a `VolumeChanged` signal.

#### `DecreaseVolume`
- **Signature**: `DecreaseVolume() -> ()`
- **Description**: Decreases master volume by the configured default step size. Emits a `VolumeChanged` signal.

#### `IncreaseVolumeBy`
- **Signature**: `IncreaseVolumeBy(step: uint8) -> ()`
- **Description**: Increases master volume by a custom step percentage. Emits a `VolumeChanged` signal.

#### `DecreaseVolumeBy`
- **Signature**: `DecreaseVolumeBy(step: uint8) -> ()`
- **Description**: Decreases master volume by a custom step percentage. Emits a `VolumeChanged` signal.

#### `ToggleMute`
- **Signature**: `ToggleMute() -> ()`
- **Description**: Inverts the current playback mute state. Emits a `MuteChanged` signal.

#### `SetMute`
- **Signature**: `SetMute(muted: boolean) -> ()`
- **Description**: Explicitly sets the playback mute state. Emits a `MuteChanged` signal.

#### `GetVolume`
- **Signature**: `GetVolume() -> uint8`
- **Description**: Queries and returns the current master volume percentage.

#### `GetMuteState`
- **Signature**: `GetMuteState() -> boolean`
- **Description**: Queries and returns whether audio playback is currently muted.

### Signals

#### `VolumeChanged`
- **Signature**: `VolumeChanged(new_volume: uint8)`
- **Description**: Emitted whenever the master volume percentage changes.

#### `MuteChanged`
- **Signature**: `MuteChanged(muted: boolean)`
- **Description**: Emitted whenever the playback mute state transitions.

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
