# RDE Logging Guide

This document defines the logging standards for all RDE Rust services and Flutter applications. Following these rules ensures that Release builds are silent, performant, and easy to debug.

## Table of Contents

- [Core Principles](#core-principles)
- [Log Levels & Usage](#log-levels--usage)
  - [ERROR](#1-error)
  - [WARN](#2-warn)
  - [INFO](#3-info)
  - [DEBUG](#4-debug)
  - [TRACE](#5-trace)
- [Logging in Hot Paths (The Loop Rule)](#logging-in-hot-paths-the-loop-rule)
- [What to Log vs. What NOT to Log](#what-to-log-vs-what-not-to-log)
- [Rust Configuration (tracing)](#rust-configuration-tracing)
- [Flutter Configuration](#flutter-configuration)

---

## Core Principles

1. **Logs are for humans, not machines.** Do not use `tracing` to debug state machines; use the debugger or write unit tests.
2. **Release builds must be quiet.** A user running RDE on a laptop should not see 50 lines of logs in `journalctl` just by changing their volume.
3. **No sensitive data.** Never log passwords, tokens, full D-Bus addresses, or user file contents.
4. **Use structured fields.** Use `tracing`'s key-value syntax (`tracing::info!(volume = 50, "Volume changed")`) instead of string concatenation.

---

## Log Levels & Usage

### 1. `ERROR`

**Meaning:** The service is broken, or an operation that the user explicitly requested has failed.

- **When to use:**
  - Failed to bind the D-Bus name.
  - Failed to connect to the supervision socket on all retry attempts.
  - A panic that was caught and handled.
  - `PermissionDenied` when writing to `/sys/class/backlight`.
- **Example:**

  ```rust
  tracing::error!(error = %e, "Failed to write brightness to sysfs");
  ```

### 2. `WARN`

**Meaning:** Something unexpected happened, but the service recovered or used a fallback.

- **When to use:**
  - `wlr-randr` is missing, so falling back to internal backlight.
  - A D-Bus signal was malformed but ignored.
  - A service re-registered with the daemon (replacing an older PID).
  - A file was deleted while reading it, but the read succeeded on retry.
- **Example:**

  ```rust
  tracing::warn!("wlr-randr not found; defaulting to internal backlight");
  ```

### 3. `INFO`

**Meaning:** Lifecycle events. Things that happen once or twice during the lifetime of the service.

- **When to use:**
  - The service starts or stops.
  - The service connects to the supervision socket.
  - The service registers with the daemon.
  - A system-level state change (e.g., "Display connected", "Theme switched to Dark").
- **Do NOT use INFO for:**
  - Volume changes, brightness changes.
  - Per-request D-Bus calls.
  - File writes.
- **Example:**

  ```rust
  tracing::info!("Volume service is ready");
  tracing::info!(variant = "dark", "Material 3 palette updated");
  ```

### 4. `DEBUG`

**Meaning:** Developer diagnostics. Things you only care about when actively debugging.

- **When to use:**
  - A volume or brightness level was set.
  - A D-Bus method was called.
  - A file was read/written.
  - A configuration was loaded.
- **Behavior:** These logs are **stripped** (or hidden) in Release builds, but visible when you run `RUST_LOG=debug`.
- **Example:**

  ```rust
  tracing::debug!(volume = 50, "Volume changed");
  tracing::debug!(path = %path.display(), "Wrote adapter file");
  ```

### 5. `TRACE`

**Meaning:** Extreme detail. Only used when hunting a very specific bug (e.g., async deadlocks, rapid polling).

- **When to use:**
  - Inside a hot loop (e.g., the audio backend reading data every 10ms).
  - Function entry/exit for deep call stacks (via `#[instrument]`).
  - Every D-Bus property change event.
- **Example:**

  ```rust
  tracing::trace!("Polling ALSA mixer state");
  ```

---

## Logging in Hot Paths (The Loop Rule)

**Never** log at `INFO` or `DEBUG` inside a loop or a fast-updating event handler.

### ❌ Bad: Spamming the journal

```rust
// Runs 60 times a second when the user drags the slider
loop {
    let vol = alsa.read_volume();
    tracing::info!("Volume is {}", vol); // This will create 60 lines per second.
}
```

### ✅ Good: Log only on change

```rust
let mut last_volume = 0;
loop {
    let vol = alsa.read_volume();
    if vol != last_volume {
        tracing::debug!("Volume changed to {}", vol); // Only logs when the value actually changes.
        last_volume = vol;
    }
}
```

---

## What to Log vs. What NOT to Log

| What to log | Level | What NOT to log |
| :--- | :--- | :--- |
| Service startup / shutdown | `INFO` | Every volume tick (1% -> 2%) |
| D-Bus name acquired | `INFO` | Every `PropertiesChanged` event |
| Theme changed to Dark/Light | `INFO` | The contents of `settings.toml` |
| Failed to connect to D-Bus | `ERROR` | Full D-Bus method payloads |
| Permission denied on sysfs | `ERROR` | User passwords or secrets |
| File write failed | `ERROR` | Every cache lookup |
| wlr-randr missing (fallback) | `WARN` | Every frame render |

---

## Rust Configuration (`tracing`)

RDE uses `tracing` with `EnvFilter`.

### The Standard Setup

Do **not** write a per-service `tracing_subscriber` setup. Every service installs
the shared logger from `rde_core`, which applies the rules above:

```rust
use rde_core::{
    fs::rde_service_logs_dir,
    logger::{LogLevel, Logger},
};

fn init_tracing() -> anyhow::Result<()> {
    let is_release_mode = cfg!(not(debug_assertions));
    let log_dir = rde_service_logs_dir(SERVICE_NAME)?;

    // Release: lifecycle events only. Debug: per-operation diagnostics too.
    let log_level = match is_release_mode {
        true => LogLevel::Info,
        false => LogLevel::Debug,
    };

    Logger::new(log_level, log_dir, SERVICE_NAME).init(is_release_mode)?;
    Ok(())
}
```

`Logger` builds the `EnvFilter` itself, scoped to the service's own crate, so
the rules are enforced in one place:

| Build | Service crate | Third-party crates (zbus, tower, …) |
| :--- | :--- | :--- |
| Debug | `debug` (`trace` if the service asks for it) | `warn` |
| Release | `info` — `debug`/`trace` are hidden | `error` |

The generated directive looks like `warn,rde_volume=debug` or, in a release
build, `error,rde_volume=info`. A service can ask for a quieter level than the
build allows (`Warn`, `Error`), but never a more verbose one.

### The Environment Override

When debugging a Release build, run:

```bash
RUST_LOG=debug rde-volume
# Or filter to just your service
RUST_LOG=rde_volume=debug rde-volume
```

---

## Flutter Configuration

For Flutter, do **not** use `print()` in Release builds. It uses CPU cycles to write to the console even when no one is looking.

### 1. Use `debugPrint`

`debugPrint` is automatically stripped in Release builds.

```dart
import 'package:flutter/foundation.dart';

void myFunc() {
  debugPrint('This only prints in Debug mode');
}
```

### 2. Use `kDebugMode` for conditional logic

```dart
if (kDebugMode) {
  print('Debug-only log');
}
```

### 3. Where to log in Flutter

- **`INFO`:** App boot, route changes, D-Bus connections.
- **`WARN`:** Bloc state fallbacks, missing config.
- **`ERROR`:** D-Bus connection failures, parse errors.

---

## Summary Checklist

Before merging a PR, ask yourself:

- [ ] Did I change 90% of my `info!` calls to `debug!`?
- [ ] Are my `debug!` calls stripped in Release mode? (Check `Cargo.toml` profile settings).
- [ ] Am I logging inside a loop that runs more than 1/sec?
- [ ] Am I logging only when state *changes*, not on every tick?
- [ ] Are my `error!` logs actually errors, or just warnings?

Following this guide will ensure RDE remains fast, its journal is readable, and debugging is a pleasant experience.
