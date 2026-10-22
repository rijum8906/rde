# RDE Brightness

RDE service for brightness control.

## Structure

- **`app/`**: Service lifecycle.
  - [`app/mod.rs`](src/app/mod.rs): global `App` singleton, D-Bus registration, signal handling, shutdown.
  - [`app/thread.rs`](src/app/thread.rs): daemon supervision task (connect, register, serve, deregister).
- **`handler/`**: Supervisor protocol handling.
  - [`handler/request.rs`](src/handler/request.rs): `HealthCheck`, `GetStatus`, `Shutdown`.
  - [`handler/response.rs`](src/handler/response.rs): `RegisterAck`.
- **`constants.rs`**: service name, D-Bus contract, and retry policy.
- **`backend.rs`**: backlight hardware abstraction (sysfs and privilege fallback).
- **`dbus/`**: `org.rde.Brightness` interface at `/org/rde/Brightness`.

## Lifecycle

1. `App::global()` installs logging and opens the backlight backend; failure is returned, not panicked.
2. `App::run()` publishes `org.rde.Brightness`, spawns the supervision task, and waits.
3. `SIGINT`, `SIGTERM`, or a supervisor `Shutdown` request triggers teardown.
4. `App::shutdown()` stops supervision and has a bounded wait for the socket task.

## DBus Interface

| Name | Type | Signature | Flag | Description
| :--- | :--- |  :--- | :--- | :--- |
| IncreaseBrightness | method | u | - | Increases brightness by `step` percentage points. |
| DecreaseBrightness | method | u | - | Decreases brightness by `step` percentage points. |
| Brightness | property | u | writable | Current brightness value. |
| BrightnessPercentage | property | u | writable | Current brightness percentage. |
| Version | property | s | emit-change | Version of the service. |
| BrightnessChanged | signal | u | - | Emitted when brightness changes. |
