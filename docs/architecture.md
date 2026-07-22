# Architecture

This document explains how RDE is structured internally and why, so contributors can extend it without breaking the design.

## Table of Contents

- [Design Goals](#design-goals)
- [Two Communication Layers](#two-communication-layers)
- [Component Responsibilities](#component-responsibilities)
- [Service Lifecycle](#service-lifecycle)
- [Crate Dependency Graph](#crate-dependency-graph)
- [Adding a New Service](#adding-a-new-service)

---

## Design Goals

1. **Isolation** — a crash in one service (e.g. `rde-volume`) must never take down the rest of the desktop environment.
2. **Standard compliance** — anything external (status bars, keyboard shortcut daemons, `polkit`) should be able to talk to RDE using plain D-Bus, without needing to know RDE-specific internals.
3. **Single source of truth per concern** — configuration, storage, and IPC framing are implemented once, in shared crates, and reused everywhere.
4. **Boring is good** — no dynamic plugin loading, no custom RPC framework beyond what's strictly needed. Prefer well-understood primitives (Unix sockets, D-Bus, JSON/TOML).

---

## Two Communication Layers

A common mistake in daemon design is letting the "internal" and "external" APIs merge into one. RDE deliberately keeps them separate:

| Layer | Transport | Audience | Purpose |
| :--- | :--- | :--- | :--- |
| **Public API** | D-Bus (session/system bus) | External tools: status bars, panels, shortcuts, `rde-cli` | The actual functionality — set volume, get brightness, switch theme |
| **Internal supervision** | Unix domain socket (`rde-ipc`) | `rde-daemon` ↔ each service | Registration, health checks, graceful restart, config-reload signals |

**Why not just use D-Bus for everything, including supervision?** Because supervision needs to work even if a service hasn't finished registering its D-Bus interface yet, and because health-check/restart traffic shouldn't be observable or forgeable by arbitrary D-Bus clients. Keeping it on a private, daemon-owned socket avoids that entirely.

**Why not build a custom RPC layer instead of D-Bus for the public API?** Because "Standard Compliant" is a stated goal — reusing D-Bus means existing desktop tooling (waybar, polybar, GNOME/KDE panels, `playerctld`-style tools) can talk to RDE with zero RDE-specific code.

---

## Component Responsibilities

```
rde-daemon        supervises services; owns no user-facing functionality itself
rde-core          fs abstractions, shared error types, generic utilities
rde-config        XDG path resolution + typed config parsing (serde/toml)
rde-ipc           internal message types + Unix socket transport (daemon <-> service only)
rde-cli           thin client that calls services' public D-Bus methods
rde-brightness    owns org.rde.Brightness; talks to sysfs directly
rde-volume        owns org.rde.Volume; talks to ALSA via zbus
rde-theme         owns org.rde.Theme; persists via rde-core's storage abstraction
rde-wifi          owns org.rde.wifi; talks to NetworkManager via system D-Bus
rde-notification  owns org.freedesktop.Notifications (WIP)
```

A service crate never talks to another service crate directly. If `rde-theme` needs to react to a brightness change (for example, auto dark-mode based on ambient light in the future), it subscribes to the relevant D-Bus signal — it does not import `rde-brightness`.

---

## Service Lifecycle

1. `rde-daemon` starts and reads its config via `rde-config`.
2. For each configured service, `rde-daemon` spawns the service process and opens a socket connection via `rde-ipc`.
3. The service sends a `Register` message over the internal socket, then claims its D-Bus bus name (e.g. `org.rde.Volume`, `org.rde.wifi`) and starts serving its public interface.
4. `rde-daemon` periodically sends `HealthCheck`; the service responds `Alive`. A missed response past a timeout threshold triggers a restart.
5. On `SIGTERM`/shutdown, `rde-daemon` sends `Shutdown` to each service over the internal socket, giving it a chance to persist state (via `rde-config`/`rde-core`) before the process exits.

See [`ipc-protocol.md`](ipc-protocol.md) for the exact message shapes used in this exchange.

---

## Crate Dependency Graph

```mermaid
graph TD
    core[rde-core] --> config[rde-config]
    core --> ipc[rde-ipc]
    config --> daemon[rde-daemon]
    ipc --> daemon
    config --> brightness[rde-brightness]
    ipc --> brightness
    config --> volume[rde-volume]
    ipc --> volume
    config --> theme[rde-theme]
    ipc --> theme
    config --> wifi[rde-wifi]
    ipc --> wifi
    config --> notification[rde-notification]
    ipc --> notification
```


No service crate depends on another service crate. Only `crates/*` are shared dependencies.

---

## Adding a New Service

1. Create `services/rde-<name>/` adhering to RDE's modular service architecture (modeled after `rde-wifi`):
   ```
   services/rde-<name>/
   ├── Cargo.toml          # Crate manifest & dependencies (rde-core, rde-ipc, zbus, etc.)
   ├── README.md           # Service spec, architecture details, & D-Bus API reference
   └── src/
       ├── lib.rs          # Crate root re-exporting modules (app, backend, dbus, domain, infra, ipc)
       ├── main.rs         # Binary entry point initializing Application singleton & running event loop
       ├── app/            # Service lifecycle & singleton manager
       │   ├── mod.rs      # Application struct, logger init, & global singleton handle
       │   ├── run.rs      # Main execution loop, D-Bus session registration, & IPC task spawn
       │   └── shutdown.rs # Graceful cleanup & teardown logic
       ├── backend/        # Domain engine & hardware/state logic
       │   ├── mod.rs      # Main backend struct & core state initialization
       │   ├── connection.rs # Connection profiles, hardware operations, & state mutations
       │   ├── device.rs   # Hardware device discovery & status queries
       │   └── tests.rs    # Unit tests with mock D-Bus sockets
       ├── dbus/           # Public Session D-Bus interface (org.rde.<name>)
       │   ├── mod.rs      # Module declarations
       │   └── iface.rs    # zbus interface implementation (properties, methods, signals)
       ├── domain/         # Domain models, enums, & event definitions
       │   ├── mod.rs      # Module declarations
       │   └── models.rs   # Data structs, status enums, & event payloads
       ├── infra/          # Low-level system D-Bus proxies & test mocks
       │   ├── mod.rs      # Conditional export of real vs mock proxies
       │   └── dbus/
       │       ├── nm_proxy.rs # zbus system D-Bus proxy traits (e.g. NetworkManager, ALSA, sysfs)
       │       └── mock.rs     # mockall test mocks for D-Bus proxies
       └── ipc/            # Unix socket IPC with rde-daemon supervisor
           ├── mod.rs      # Module declarations
           ├── handler.rs  # IpcHandler, registration handshake, & socket event loop
           ├── daemon_request.rs  # Supervisor request handlers (HealthCheck, GetStatus, Shutdown)
           └── daemon_response.rs # Supervisor response handlers (RegisterAck)
   ```

2. **Where to Put What**:
   - **Binary & Application Bootstrapping (`main.rs`, `app/`)**: Put process startup, logger setup (`rde_core::logger`), signal handlers (`Ctrl+C`), D-Bus session bus setup (`org.rde.<name>`), and IPC connection retry loops here.
   - **Core Engine & Hardware Logic (`backend/`)**: Put hardware device detection, state management, NetworkManager/sysfs interactions, and backend tests here. Keep it decoupled from D-Bus presentation.
   - **Public API Interface (`dbus/`)**: Put `zbus` `#[interface(name = "org.rde.<name>")]` code here. Translate incoming D-Bus calls into `backend` method calls and emit D-Bus signals (`*Changed`, `Completed`).
   - **Data Types (`domain/`)**: Put pure Rust data structures, status enums, and event types here. Derive `Serialize`, `Deserialize`, `zbus::zvariant::Type`, and `zbus::zvariant::Value` as needed.
   - **Drivers & System Proxies (`infra/`)**: Put low-level `zbus` proxies (`#[proxy]`) for talking to system daemons or hardware interfaces, along with `mockall` mocks for unit testing.
   - **Supervisor Communications (`ipc/`)**: Put socket client (`rde-ipc`) handling, registration handshake with `rde-daemon`, and responses to `HealthCheck` liveness probes here.

3. Add the new service to workspace `Cargo.toml` members.
4. Depend on `rde-core`, `rde-config`, and `rde-ipc` — never import another service crate directly.
5. Register the service in `rde-daemon` so it is supervised automatically.
6. Document its public D-Bus API in `README.md` and update [`dbus-api.md`](dbus-api.md).
7. Add integration test coverage under `tests/` or `backend/tests.rs`.

