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
   - **Module & Crate Docs (`//!`)**: Every crate and module file must begin with a concise top-level documentation comment: a title, a spacer line, and a one-to-two-sentence description of the module's responsibility.

     ```rust
     //! # <Module / Feature Title>
     //!
     //! <Short description of module purpose and architecture>
     ```

     Do not add `Features`, `Related`, `Authors`, `License`, or `Copyright` sections to module headers; keep those details in crate-level docs, the service README/ARCHITECTURE files, or symbol rustdoc.
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

## Commit Guidelines

This repository uses [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) with project-specific scopes. Every commit must be **atomic** (one logical change, compiles on its own, passes tests on its own, revertable on its own) and follow the format `<type>(<scope>)!: <subject>` followed by an optional body and footer. Allowed types are `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `build`, `ci`, `chore`, `style`, and `revert` — no `wip`, `temp`, `fixup`, `oops`, or `misc`. Scopes are lowercase, singular, and match the module or trait being changed: `core`, `domain`, `resolver`, `store`, `adapter`, `registry`, `service`, `dbus`, `app`, or `deps`. Use `!` after the scope (or type) to mark a breaking change, and include a `BREAKING CHANGE:` footer describing the break. The subject line is imperative mood (`add`, not `added` or `adds`), lowercase, no trailing period, and at most 72 characters — write it as if completing "If applied, this commit will…". If a subject needs the word "and" to describe what it does, the commit is doing two things and must be split. The body (separated from the subject by a blank line, wrapped at 72 characters) explains **why** the change was made, why this approach was chosen over the alternatives, and anything non-obvious a reviewer would otherwise ask about — the diff already shows *what* changed, so don't repeat it. Use the footer for `Closes: #N`, `Refs: #N`, `Co-authored-by: Name <email>`, and `BREAKING CHANGE:` lines. Before pushing, rebase onto `main` (`git rebase main`) rather than merging — merge commits are noise and the history should stay linear. During review, create fixup commits (`git commit --fixup=<hash>`) instead of amending, and squash them with `git rebase -i --autosquash main` before merge so the review feedback disappears into the original commit. A reviewer should be able to read the commit messages in order and understand the entire change without opening a single diff; if they can't, the commits need to be rebased, split, or rewritten. When in doubt, prefer more, smaller commits over fewer, larger ones — a five-commit feature PR that reads as a story ("add capability field" → "add adapter" → "expose over D-Bus" → "add test" → "update docs") is better than a one-commit 800-line dump, and it's dramatically better than a ten-commit trail of "wip" → "fix tests" → "address review" → "fix clippy" → "really fix tests."

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
