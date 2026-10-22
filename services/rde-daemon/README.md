# RDE Daemon

Supervision service for the Riju Desktop Environment (RDE).

`rde-daemon` owns the internal Unix socket that every other RDE service connects
to. It keeps a registry of running services, validates the supervision protocol
version, and shuts down cleanly with the session. It deliberately exposes no
user-facing D-Bus API — each service owns its own interface directly.

## Architecture

```
src/
├── app/        # Global daemon state and the service registry
├── handler/    # Request/response processing for connected services
├── ipc/        # Supervision socket server and per-connection sessions
├── lib.rs      # Crate documentation and module exports
└── main.rs     # Binary entry point (logging, startup, signal handling)
```

## Runtime Behaviour

- **Socket**: `$XDG_RUNTIME_DIR/rde/rde.sock`, mode `0600`, created on startup
  and removed on shutdown. Services connect as clients and stay connected for
  their lifetime.
- **Registration**: a service sends `Register` and receives `RegisterAck`; the
  daemon tracks its name, PID, version, and status.
- **Cleanup**: when a connection closes, the service is removed from the
  registry so a later reconnection starts from a clean state.
- **Shutdown**: `SIGINT` or `SIGTERM` stops the accept loop and removes the
  socket file. In-flight sessions end with the process.

## Running

```bash
cargo run --bin rde-daemon
```

Logs are written to `~/.local/rde/logs/daemon/`.

## Related Documentation

- [IPC Protocol Design](../../docs/ipc-protocol.md)
- [Architecture Design](../../docs/architecture.md)
