//! # Daemon Application State
//!
//! Owns the supervisor's global runtime state: version information, running
//! status, and the registry of services connected over the supervision socket.
//!
//! ## Features
//! - Poison-safe global singleton access via [`App::with_global`]
//! - Encapsulated service registry (no shared `Arc<Mutex<_>>` handed to callers)
//! - Uptime tracking derived from the start [`Instant`]
//!
//! ## Related
//! - [`crate::ipc::server`]: registers and deregisters services through this state
//! - [`crate::handler::request`]: mutates service status on incoming requests
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::{
    collections::HashMap,
    sync::{Mutex, OnceLock},
    time::Instant,
};

use rde_core::errors::{RdeError, RdeResult};
use rde_ipc::message::{ServiceInfo, ServiceStatus};

/// Process-wide daemon state, initialised on first use.
static APP_INSTANCE: OnceLock<Mutex<App>> = OnceLock::new();

/// Supervisor state shared by every connection handler.
///
/// # Fields
/// - `version`: daemon version taken from `CARGO_PKG_VERSION`
/// - `is_running`: whether the supervisor lifecycle has been started
/// - `start_time`: instant the supervisor started, used for uptime reporting
/// - `services`: registered services keyed by their service name
#[derive(Debug)]
pub struct App {
    /// Daemon version string (`CARGO_PKG_VERSION`).
    version: String,

    /// Whether the supervisor lifecycle has been started.
    is_running: bool,

    /// Instant at which the supervisor started.
    start_time: Option<Instant>,

    /// Registry of connected services, keyed by service name.
    services: HashMap<String, ServiceInfo>,
}

impl App {
    /// Creates an empty application state.
    ///
    /// The daemon's logger is initialised by the binary entry point, so this
    /// constructor is side-effect free and cannot fail.
    pub fn new() -> Self {
        Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
            is_running: false,
            start_time: None,
            services: HashMap::new(),
        }
    }

    /// Returns the process-wide application state.
    ///
    /// Prefer [`App::with_global`] over locking this mutex directly, so that
    /// lock poisoning is translated into a domain error instead of a panic.
    pub fn global() -> &'static Mutex<App> {
        APP_INSTANCE.get_or_init(|| Mutex::new(App::new()))
    }

    /// Runs `operation` against the global state under an exclusive lock.
    ///
    /// # Errors
    /// Returns [`RdeError::Internal`] if a previous holder panicked while the
    /// lock was held, leaving the mutex poisoned.
    ///
    /// # Returns
    /// The value produced by `operation`.
    pub fn with_global<T>(operation: impl FnOnce(&mut App) -> T) -> RdeResult<T> {
        let mut app = App::global()
            .lock()
            .map_err(|_| RdeError::Internal("daemon state lock is poisoned".to_string()))?;

        Ok(operation(&mut app))
    }

    /// Marks the supervisor as running and records the start instant.
    pub fn start(&mut self) {
        self.is_running = true;
        self.start_time = Some(Instant::now());
    }

    /// Marks the supervisor as stopped and clears transient runtime state.
    ///
    /// Registered services are dropped here because every supervised process is
    /// expected to exit during daemon shutdown.
    pub fn stop(&mut self) {
        let registered = self.services.len();
        self.services.clear();
        self.is_running = false;
        self.start_time = None;

        tracing::debug!(
            cleared_services = registered,
            "Daemon state reset for shutdown"
        );
    }

    /// Returns the daemon version string.
    pub fn version(&self) -> &str {
        &self.version
    }

    /// Returns whether the supervisor lifecycle is currently running.
    pub fn is_running(&self) -> bool {
        self.is_running
    }

    /// Returns the number of whole seconds since the supervisor started.
    ///
    /// # Returns
    /// `None` while the supervisor is not running.
    pub fn uptime_secs(&self) -> Option<u64> {
        self.start_time.map(|start| start.elapsed().as_secs())
    }

    /// Inserts or replaces a service in the registry.
    ///
    /// # Returns
    /// The previously registered entry for the same service name, if any.
    pub fn register(&mut self, service: ServiceInfo) -> Option<ServiceInfo> {
        self.services.insert(service.id.name.clone(), service)
    }

    /// Removes a service from the registry.
    ///
    /// # Returns
    /// The removed entry, or `None` if no service with that name was registered.
    pub fn deregister(&mut self, name: &str) -> Option<ServiceInfo> {
        self.services.remove(name)
    }

    /// Updates the status of a registered service.
    ///
    /// # Returns
    /// `true` if the service was found and updated, `false` otherwise.
    pub fn update_status(&mut self, name: &str, status: ServiceStatus) -> bool {
        match self.services.get_mut(name) {
            Some(service) => {
                service.status = status;
                true
            }
            None => false,
        }
    }

    /// Returns a registered service by name.
    pub fn service(&self, name: &str) -> Option<&ServiceInfo> {
        self.services.get(name)
    }

    /// Returns an iterator over every registered service.
    pub fn services(&self) -> impl Iterator<Item = &ServiceInfo> {
        self.services.values()
    }

    /// Returns the number of registered services.
    pub fn service_count(&self) -> usize {
        self.services.len()
    }
}

impl Default for App {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use std::time::SystemTime;

    use rde_ipc::message::ServiceId;

    use super::*;

    /// Builds a registry entry for `name`.
    fn service(name: &str) -> ServiceInfo {
        ServiceInfo {
            id: ServiceId {
                name: name.to_string(),
                pid: 4242,
            },
            status: ServiceStatus::Running,
            uptime: Some(SystemTime::now()),
            restart_count: 0,
            version: "0.1.0".to_string(),
        }
    }

    #[test]
    fn register_deregister_roundtrip() {
        let mut app = App::new();

        assert!(app.register(service("brightness")).is_none());
        assert_eq!(app.service_count(), 1);
        assert!(app.service("brightness").is_some());

        let removed = app.deregister("brightness");
        assert!(removed.is_some(), "registered service should be removed");
        assert_eq!(app.service_count(), 0);
        assert!(app.deregister("brightness").is_none());
    }

    #[test]
    fn register_replaces_existing_entry() {
        let mut app = App::new();

        app.register(service("volume"));
        let previous = app.register(service("volume"));

        assert!(
            previous.is_some(),
            "re-registration should return old entry"
        );
        assert_eq!(app.service_count(), 1);
    }

    #[test]
    fn update_status_requires_registration() {
        let mut app = App::new();
        app.register(service("theme"));

        assert!(app.update_status("theme", ServiceStatus::Unhealthy));
        assert_eq!(
            app.service("theme").map(|service| &service.status),
            Some(&ServiceStatus::Unhealthy)
        );

        assert!(!app.update_status("missing", ServiceStatus::Dead));
    }

    #[test]
    fn lifecycle_tracks_running_state_and_uptime() {
        let mut app = App::new();
        assert!(!app.is_running());
        assert!(app.uptime_secs().is_none());

        app.start();
        assert!(app.is_running());
        assert!(app.uptime_secs().is_some());

        app.register(service("wifi"));
        app.stop();
        assert!(!app.is_running());
        assert!(app.uptime_secs().is_none());
        assert_eq!(app.service_count(), 0);
    }

    #[test]
    fn with_global_operates_on_shared_state() -> RdeResult<()> {
        App::with_global(|app| app.register(service("notification")))?;

        let count = App::with_global(|app| app.service_count())?;
        assert_eq!(count, 1);

        App::with_global(|app| app.deregister("notification"))?;
        Ok(())
    }
}
