# RDE Wi-Fi Service (`rde-wifi`)

An independent, decoupled system microservice for managing wireless interfaces and connections within the Riju Desktop Environment (RDE). It interacts directly with `NetworkManager` on the system D-Bus and registers with the RDE supervisor daemon over a Unix Domain Socket (UDS) IPC channel.

---

## 🛠️ Architecture Overview

The crate is structured as follows:
- **`app/`**: Core daemon lifecycle control, handling start, run, and graceful shutdown sequence.
- **`backend/`**: Modular logic for interacting with NetworkManager D-Bus proxies.
  - [`backend/device.rs`](file:///home/rijum/Projects/rde/services/rde-wifi/src/backend/device.rs): Interfaces with network device properties, scan triggers, and hardware state flags.
  - [`backend/connection.rs`](file:///home/rijum/Projects/rde/services/rde-wifi/src/backend/connection.rs): Manages network activation, profile deletions, active connection lookup, and saved credentials queries.
- **`dbus/`**: D-Bus interface wrapper.
  - [`dbus/iface.rs`](file:///home/rijum/Projects/rde/services/rde-wifi/src/dbus/iface.rs): The public D-Bus object mapping properties, methods, and signals to the external environment.
- **`infra/`**: NetworkManager client interface bindings and mocks for testing.
- **`ipc/`**: Supervision protocol handler for registration and connection checking.
- **`domain/`**: Pure domain structs and representation types.

---

## 📡 D-Bus API Reference

The service publishes its interface on the **session bus**:
- **Service Name**: `org.rde.wifi`
- **Object Path**: `/org/rde/wifi`
- **Interface**: `org.rde.wifi`

### Properties

| Property Name | Type | Access | Description |
|---|---|---|---|
| `Version` | `String` | Read-only | Returns the service version. |
| `Networks` | `Vec<AccessPointInfo>` | Read-only | List of currently visible and scanned access points. |
| `Enabled` | `bool` | Read-write | Gets or sets whether the Wi-Fi radio is enabled. |
| `SavedNetworks` | `Vec<String>` | Read-only | List of SSIDs of all saved Wi-Fi connection profiles. |

### Methods

#### `Scan`
- **Signature**: `Scan() -> ()`
- **Description**: Initiates a non-blocking background scan of visible networks. Emits `ScanCompleted` on success.

#### `GetCurrentConnection`
- **Signature**: `GetCurrentConnection() -> Vec<AccessPointInfo>`
- **Description**: Returns details of the currently active connection. If not connected, returns an empty list.

#### `ForgotDevice`
- **Signature**: `ForgotDevice(ssid: String) -> ()`
- **Description**: Deletes the saved connection profile configuration for the specified SSID.

#### `Connect`
- **Signature**: `Connect(ssid: String, password: String) -> ()`
- **Description**: Connects to the wireless network using credentials. Emits transition signals through `ConnStateChanged`.

#### `ConnectSavedNetwork`
- **Signature**: `ConnectSavedNetwork(ssid: String) -> ()`
- **Description**: Connects to a saved network (passwordless profile lookup). Emits transition signals through `ConnStateChanged`.

#### `Disconnect`
- **Signature**: `Disconnect() -> ()`
- **Description**: Disconnects from the current network, changing the interface state. Emits a `ConnStateChanged` signal.

### Signals

#### `ScanCompleted`
- **Description**: Fired immediately when a requested Wi-Fi network scan finishes.

#### `EnabledChanged`
- **Parameters**: `enabled: bool`
- **Description**: Fired when the radio enable state changes.

#### `ConnStateChanged`
- **Parameters**: `state: String`, `ssid: String`
- **Description**: Fired when the active connection state transitions. `state` can be `"Connecting"`, `"Connected"`, `"Disconnected"`, or `"Failed"`.

---

## 📦 Domain Models

All data transfer objects and serialized enum representations (such as `AccessPointInfo` and `SecurityType`) are defined inside:
- [domain/models.rs](file:///home/rijum/Projects/rde/services/rde-wifi/src/domain/models.rs)

---

## ⚙️ Development Commands

To run lints and formatting on the crate:
```bash
cargo fmt --all
cargo clippy --package rde-wifi --all-targets -- -D warnings
cargo test --package rde-wifi
```
