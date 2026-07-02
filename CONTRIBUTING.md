# Contributing to RDE

Thanks for your interest in contributing to RDE. This document covers everything you need to get a change merged.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Project Layout](#project-layout)
- [Coding Standards](#coding-standards)
- [Commit Messages](#commit-messages)
- [Branching](#branching)
- [Pull Request Process](#pull-request-process)
- [Adding a New Service](#adding-a-new-service)
- [Reporting Bugs](#reporting-bugs)
- [Reporting Security Issues](#reporting-security-issues)

---

## Code of Conduct

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## Getting Started

### Prerequisites

- Rust toolchain (`rustc` + `cargo`), edition 2024 recommended
- D-Bus (system/session bus)
- ALSA development headers (`libasound2-dev` on Debian/Ubuntu) — needed to build `rde-volume`
- Polkit — needed to test `rde-brightness`'s privileged paths

### Setup

```bash
git clone https://github.com/rijum8906/rde.git
cd rde
cargo build --workspace
cargo test --workspace
```

## Project Layout

See [`docs/architecture.md`](docs/architecture.md) for the full design rationale. In short:

- `crates/` — shared libraries only, no binaries.
- `services/` — one crate per independent service binary.
- `cli/rde-cli/` — the command-line client.
- `assets/` — systemd units, polkit policies, default config, installed by packages.
- `packaging/` — distro packaging metadata (see [`docs/packaging.md`](docs/packaging.md)).

## Coding Standards

Before opening a PR, run:

```bash
cargo fmt --all
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

CI enforces all three; a PR that fails any of them won't be merged. A few project-specific conventions:

- **No service-to-service imports.** A service under `services/` must never depend on another service crate — only on `rde-core`, `rde-config`, `rde-ipc`. Cross-service communication happens over D-Bus, not Rust function calls.
- **Public D-Bus methods must emit a `*Changed` signal** on any state mutation. Don't add a mutating method without its corresponding signal — see [`docs/dbus-api.md`](docs/dbus-api.md) for the existing pattern.
- **Internal-only messages go through `rde-ipc`**, never D-Bus. If you're tempted to add a daemon↔service message as a D-Bus method instead, it probably belongs in [`docs/ipc-protocol.md`](docs/ipc-protocol.md) instead.
- Prefer returning `Result<T, E>` with a typed error over `panic!`/`unwrap()` in anything reachable from a running service — a panic in a service should be a bug, not a control-flow tool.

## Commit Messages

RDE follows [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

[optional body]

[optional footer(s)]
```

Common types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`. Scope is typically the crate/service name, e.g.:

```
feat(rde-volume): add mute toggle to D-Bus interface
fix(rde-daemon): correct restart backoff calculation
docs(dbus-api): document ThemeChanged signal
```

## Branching

- `main` is always releasable.
- Branch from `main` using `type/short-description`, e.g. `feat/volume-mute-toggle`, `fix/daemon-restart-loop`.
- Rebase on `main` before opening a PR; avoid merge commits in feature branches.

## Pull Request Process

1. Open an issue first for anything non-trivial (new service, protocol change, packaging change) so design gets discussed before code is written.
2. Fill out the PR template — link the issue, describe the change, note any breaking changes to the D-Bus API or IPC protocol.
3. Ensure `cargo fmt`, `cargo clippy`, and `cargo test` all pass locally.
4. If your change touches `docs/dbus-api.md`-relevant interfaces or `docs/ipc-protocol.md`-relevant messages, update those docs in the same PR.
5. A maintainer will review; expect at least one round of feedback for anything beyond a trivial fix.
6. PRs are merged via squash-merge to keep `main` history readable.

## Adding a New Service

Full walkthrough in [`docs/architecture.md#adding-a-new-service`](docs/architecture.md#adding-a-new-service). Short version: mirror the existing service shape (`main.rs` / `dbus/iface.rs`), depend only on the shared crates, register with `rde-daemon`, and document the new D-Bus interface before merging.

## Reporting Bugs

Use the **Bug Report** issue template. Include your distro, RDE version (`rde-cli --version`), and steps to reproduce. Logs from `journalctl --user -u rde-daemon` are usually the fastest way to get a fix.

## Reporting Security Issues

Do **not** open a public issue for security vulnerabilities. See [`SECURITY.md`](SECURITY.md) for the reporting process.
