# RDE Theme

RDE service for theme control.

## Structure

- **`app/`**: Service lifecycle.
  - [`app/mod.rs`](src/app/mod.rs): global `App` singleton, D-Bus registration, signal handling, shutdown.
  - [`app/thread.rs`](src/app/thread.rs): daemon supervision task (connect, register, serve, deregister).
- **`handler/`**: Supervisor protocol handling.
  - [`handler/request.rs`](src/handler/request.rs): `HealthCheck`, `GetStatus`, `Shutdown`.
  - [`handler/response.rs`](src/handler/response.rs): `RegisterAck`.
- **`constants.rs`**: service name, D-Bus contract, and retry policy.
- **`dbus/`**: `org.rde.Theme` interface at `/org/rde/Theme`.
- **`domain/`**: theme, Material 3, and GTK models.
- **`backend.rs`**: reserved for palette generation and toolkit writers.

## Lifecycle

1. `App::global()` installs logging and creates the D-Bus object.
2. `App::run()` publishes `org.rde.Theme`, spawns the supervision task, and waits.
3. `SIGINT`, `SIGTERM`, or a supervisor `Shutdown` request triggers teardown.
4. `App::shutdown()` stops supervision and has a bounded wait for the socket task.

## Current Features

- Service lifecycle, logging, and daemon supervision
- D-Bus object with properties, methods, and signals (most methods are still stubs)

## Upcoming Features

- Create a Theme from Primary, Secondary, and Accent colors
- Delete, Uninstall a Theme
- Change accent color
- Qt Color Palette
