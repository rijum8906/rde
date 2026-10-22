# RDE Notification

RDE service for notification control.

## Status

The service lifecycle and daemon supervision are implemented. The D-Bus surface
(`org.rde.Notification` at `/org/rde/Notification`) and the notification queue
backend are still placeholders.

## Structure

- **`app/`**: Service lifecycle.
  - [`app/mod.rs`](src/app/mod.rs): global `App` singleton, signal handling, shutdown.
  - [`app/thread.rs`](src/app/thread.rs): daemon supervision task (connect, register, serve, deregister).
- **`handler/`**: Supervisor protocol handling.
  - [`handler/request.rs`](src/handler/request.rs): `HealthCheck`, `GetStatus`, `Shutdown`.
  - [`handler/response.rs`](src/handler/response.rs): `RegisterAck`.
- **`constants.rs`**: service name and retry policy.
- **`dbus/`**: reserved for the notification interface.
- **`backend.rs`**: reserved for the notification queue.

## Lifecycle

1. `App::global()` installs logging and the runtime state.
2. `App::run()` spawns the supervision task and waits.
3. `SIGINT`, `SIGTERM`, or a supervisor `Shutdown` request triggers teardown.
4. `App::shutdown()` stops supervision and has a bounded wait for the socket task.
