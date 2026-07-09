# Developer Agent Guidelines (AGENTS.md)

Welcome! This file provides instructions, context, and rules of engagement for AI coding assistants and autonomous agents (like Antigravity) working on the Riju Desktop Environment (RDE) repository.

---

## 🛠️ Codebase Overview

RDE is structured as a Cargo workspace consisting of:
- **`crates/`**: Core shared libraries (no standalone binaries).
  - [rde-core](/crates/rde-core): Filesystem abstractions, logging (`tracing`), and global error handling (`RdeError`/`RdeResult`).
  - [rde-config](/crates/rde-config): XDG path resolution and configuration parsing.
  - [rde-ipc](/crates/rde-ipc): Internal Unix socket messaging primitives.
- **`services/`**: Independent, decoupled microservices.
  - `rde-daemon`: Supervisor daemon checking health and restarting services.
  - `rde-brightness`, `rde-volume`, `rde-theme`, `rde-notification`: Public D-Bus-facing services.
- **`cli/rde-cli`**: Lightweight user CLI client.
- **`docs/`**: Technical specs, architecture design, and D-Bus/IPC schemas.

---

## 🛑 Strict Rules & Conventions

To maintain codebase integrity, all agents must adhere to the following rules:

1. **No Service-to-Service Dependency**:
   - Services under `services/` must *never* import or depend on one another.
   - All inter-service cooperation must happen asynchronously via public D-Bus interfaces or supervision IPC channels.
2. **Conventional Commits**:
   - Commit messages must follow the [Conventional Commits](https://www.conventionalcommits.org/) spec.
   - Use the appropriate scope in parentheses, e.g., `feat(rde-volume): add mute toggle` or `fix(rde-core): correct log rotation`.
3. **Rust Coding Standards**:
   - Avoid `panic!`, `.unwrap()`, and `.expect()` in non-test production code. Always bubble up errors using `Result<T, E>` and the custom `RdeError` type.
   - Always run the lint/test suite before finalizing changes.

---

## ⚙️ Development Commands

Ensure these commands run and pass without errors/warnings before submitting any changes:

```bash
# Format codebase
cargo fmt --all

# Run lints (strict warnings as errors)
cargo clippy --workspace --all-targets -- -D warnings

# Execute workspace tests
cargo test --workspace
```

---

## 📖 Key Documentation Links
- [Architecture Design](/docs/architecture.md)
- [D-Bus API Reference](/docs/dbus-api.md)
- [IPC Protocol Design](/docs/ipc-protocol.md)
- [Contributing Guidelines](/CONTRIBUTING.md)
