// src/backend/mod.rs

use std::path::PathBuf;

use crate::{
    backend::{BackendError, BackendKind},
    domain::ResolvedTheme,
};

/// Static metadata about an adapter, available before any IO.
///
/// Returned by `Adapter::capabilities()`. The service and the D-Bus layer
/// read this to decide *whether* to call `apply`, and to report to clients
/// what the current session supports.
#[derive(Debug, Clone)]
pub struct AdapterCapabilities {
    /// Which surface this adapter renders. Used in logs and in D-Bus
    /// properties (`active_backend`).
    pub backend: BackendKind,

    /// Whether a successful `apply` is visible to running apps without a
    /// relaunch. Plasma/LXQt/GNOME: true. qt6ct: false (next launch only).
    pub is_live: bool,

    /// Whether this adapter is the *primary* surface for the current
    /// session. Primary failure aborts the transaction; secondary failure
    /// is logged and reported via `ServiceError::PartialApply`.
    pub is_primary: bool,

    /// Whether the adapter needs the session environment wired up before
    /// it can read what the adapter writes (Hyprland + qt6ct without
    /// `QT_QPA_PLATFORMTHEME`). The UI surfaces this as a prompt.
    pub requires_env_wiring: bool,
}

/// A surface adapter: renders a `ResolvedPalette` into one desktop's
/// on-disk format and optionally notifies the desktop to re-read.
///
/// Implementations live in `backend/surfaces/<name>.rs`. They are the ONLY
/// place in the service that touches desktop config files. They do not
/// resolve palettes (the resolver does that) and do not persist seeds
/// (the store does that).
pub trait Adapter: Send + Sync {
    // ─── Required ───────────────────────────────────────────────────────

    /// Static metadata. Pure: no IO, no side effects, cheap to call.
    /// Called by the registry during `select`, by the service during
    /// `apply`, and by the D-Bus layer for read-only properties.
    fn capabilities(&self) -> AdapterCapabilities;

    /// Render `palette` into this adapter's surface, returning the paths
    /// written. Must be idempotent: calling twice with the same palette
    /// produces the same files. Must be atomic per-file (use
    /// `core::fs::atomic_write`). Must not touch files outside its own
    /// surface (no `theme.json`, no other desktop's config).
    fn apply(&self, palette: &ResolvedTheme) -> Result<Vec<PathBuf>, BackendError>;

    /// Tell the desktop to re-read its config. Called *after* `apply`
    /// succeeds and *after* the store commits. Must be best-effort: a
    /// failed notification does not fail the transaction (the files are
    /// already written; the next app launch will see them). Returns
    /// `Ok(())` when the adapter has no notification mechanism (qt6ct).
    fn notify_changed(&self, written: &[PathBuf]) -> Result<(), BackendError>;

    // ─── Default ────────────────────────────────────────────────────────

    /// The seeds this adapter needs to persist alongside its rendered
    /// output so `LoadThemeCatalog` can recover after a partial failure.
    ///
    /// Default: `None` — the service persists seeds via `ThemeStore`
    /// (which all adapters share), so most adapters don't need this.
    /// Override only if this surface requires *additional* state that
    /// `theme.json` cannot carry (e.g. a per-monitor variant).
    fn extra_state(&self) -> Option<&dyn std::any::Any> {
        None
    }
}
