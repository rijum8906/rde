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
   - Use the appropriate scope in parentheses, e.g., `feat(rde-volume): add mute toggle`, `docs(rde-wifi): add inline comments`, or `fix(rde-core): correct log rotation`.
3. **Rust Coding Standards**:
   - Avoid `panic!`, `.unwrap()`, and `.expect()` in non-test production code. Always bubble up errors using `Result<T, E>` and the custom `RdeError` type.
   - Always run the lint/test suite before finalizing changes.

---

## 🎨 Coding Style & Guidelines

Agents working on RDE must follow these specific coding style standards:

1. **Comprehensive Documentation & Comments**:
   - **Module & Crate Docs (`//!`)**: Every crate and module file must begin with a top-level module documentation comment following the standard file comment boilerplate schema:
     ```rust
     //! # <Module / Feature Title>
     //!
     //! <Detailed description of module purpose and architecture>
     //!
     //! ## Features
     //! - <Feature 1>
     //! - <Feature 2>
     //!
     //! ## Related
     //! - <Related modules, traits, or specifications>
     //!
     //! ## Authors
     //! - Riju Mondal <rijum8906@gmail.com>
     //!
     //! ## License
     //! MIT License (see LICENSE file for details)
     //!
     //! ## Copyright
     //! Copyright (c) 2026 Riju Mondal. All rights reserved.
     ```
   - **Symbol Rustdoc (`///`)**: All public structs, enums, fields, functions, methods, traits, and D-Bus properties/methods must have detailed rustdoc comments explaining parameters, return values (`# Returns`), error conditions (`# Errors`), and execution steps.
   - **Step-by-Step Inline Comments (`//`)**: Use numbered/step-by-step inline comments inside function bodies to clarify non-obvious logic, algorithm flow, D-Bus property dict construction, hardware interaction routines, and fallback error paths.
2. **Resilient Error Handling**:
   - Never let service processes crash unexpectedly. In non-fatal scenarios (such as transient D-Bus disconnects or missing non-critical hardware devices), handle errors gracefully, log warnings with full context, and allow the service loop to continue running.
   - Always map external D-Bus or IPC errors into the domain error type (`RdeError`).
3. **Structured Tracing & Logging**:
   - Use `tracing` macros (`info!`, `warn!`, `error!`, `debug!`) for operational state transitions and diagnostics rather than standard `println!`.
   - Provide informative log messages containing relevant context (e.g. object paths, attempt numbers, error messages).
4. **Verification Before Committing**:
   - Never submit code edits without verifying that formatting, linting, and tests pass cleanly across the entire Cargo workspace (`cargo fmt`, `cargo clippy`, `cargo test`).

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

