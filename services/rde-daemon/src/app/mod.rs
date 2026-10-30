//! Global daemon state for the service supervisor.
//!
//! [`App`] is the single owner of the supervisor's runtime state: the daemon
//! version, whether the lifecycle has started, the start [`Instant`] used for
//! uptime, the registry of services connected over the supervision socket,
//! and the child processes of the RDE services the supervisor spawned.
//!
//! Access is through [`App::with_global`], which locks the process-wide
//! instance and translates lock poisoning into [`RdeError::Internal`] instead
//! of panicking. Callers never see the `Arc<Mutex<_>>`; they get a `&mut App`
//! inside a closure.
//!
//! The registry (`services`) and the child-process table (`children`) are
//! separate: a service can be registered over the socket without a
//! corresponding child (it was started by `systemd --user`, not by the
//! supervisor), and a child can be running without having registered yet (it
//! is still starting). The settings page combines [`App::is_alive`] and
//! [`App::service`] to decide which state to show.

use std::{
    collections::HashMap,
    process::{Child, Command, Stdio},
    sync::{Mutex, OnceLock},
    time::Instant,
};

use rde_core::errors::{RdeError, RdeResult};
use rde_ipc::message::{ServiceInfo, ServiceStatus};

use crate::backend::detect::{self, RdeService};

/// Process-wide daemon state, initialised on first use.
static APP_INSTANCE: OnceLock<Mutex<App>> = OnceLock::new();

/// Supervisor state shared by every connection handler.
///
/// A single `App` lives for the process's lifetime. The fields are grouped by
/// concern: identity (`version`), lifecycle (`is_running`, `start_time`),
/// supervision (`installed_rde_services`, `children`, `start_failures`), and
/// the socket registry (`services`).
#[derive(Debug)]
pub struct App {
    /// Daemon version string (`CARGO_PKG_VERSION`).
    version: String,

    /// Whether the supervisor lifecycle has been started.
    is_running: bool,

    /// Instant at which the supervisor started.
    start_time: Option<Instant>,

    /// Registry of connected services, keyed by service name.
    ///
    /// Populated by the IPC server when a service registers over the
    /// supervision socket; not touched by [`App::start`].
    services: HashMap<String, ServiceInfo>,

    /// RDE services detected as installed at startup.
    ///
    /// Captured once in [`App::new`] so the settings page can list every
    /// installed service, including ones the supervisor hasn't started yet.
    installed_rde_services: Vec<RdeService>,

    /// Child processes the supervisor spawned in [`App::start`], keyed by
    /// service.
    ///
    /// Only services that spawned successfully are here; a service that
    /// failed to spawn is in [`App::start_failures`] instead.
    children: HashMap<RdeService, Child>,

    /// Services that were installed but failed to spawn, with the reason.
    ///
    /// The settings page shows "installed but failed to start: <reason>"
    /// rather than silently omitting the card.
    start_failures: HashMap<RdeService, String>,
}

impl App {
    /// Creates an empty application state.
    ///
    /// Detects installed RDE services, so it touches the filesystem and
    /// `PATH`. The daemon's logger is initialised by the binary entry point,
    /// so this constructor logs nothing.
    pub fn new() -> Self {
        Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
            is_running: false,
            start_time: None,
            services: HashMap::new(),
            installed_rde_services: detect::detect_services(),
            children: HashMap::new(),
            start_failures: HashMap::new(),
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

    /// Marks the supervisor as running, records the start instant, and spawns
    /// each installed RDE service.
    ///
    /// A service that fails to spawn does not abort the start: the others
    /// still come up, and the failure is recorded in `start_failures` so the
    /// settings page can show it. Children are stored in `children` so
    /// [`App::stop`] can terminate them and [`App::poll`] can reap them.
    ///
    /// Idempotent: calling `start` on an already-running supervisor is a
    /// no-op, so a re-entrant request from the IPC server can't double-spawn.
    pub fn start(&mut self) {
        if self.is_running {
            return;
        }

        self.is_running = true;
        self.start_time = Some(Instant::now());
        self.children.clear();
        self.start_failures.clear();

        // Capture the installed list before iterating, so a service that
        // gets installed mid-loop is picked up on the next `start` rather
        // than causing a borrow conflict with `self`.
        let installed = self.installed_rde_services.clone();
        for service in installed {
            match spawn_service(service) {
                Ok(child) => {
                    tracing::info!(service = service.bin_name(), "started service");
                    self.children.insert(service, child);
                }
                Err(error) => {
                    tracing::warn!(
                        service = service.bin_name(),
                        %error,
                        "failed to start service"
                    );
                    self.start_failures.insert(service, error);
                }
            }
        }
    }

    /// Marks the supervisor as stopped, terminates its children, and clears
    /// transient runtime state.
    ///
    /// Each child gets `SIGTERM`, then up to three seconds to exit, then
    /// `SIGKILL`. The child is reaped either way, so no zombies are left
    /// behind. The socket registry (`services`) is cleared last, because the
    /// services registered there are expected to deregister on their own
    /// before this runs — clearing it here is a safety net, not the primary
    /// path.
    pub fn stop(&mut self) {
        if !self.is_running {
            return;
        }

        for (service, child) in self.children.drain() {
            terminate_child(service, child);
        }
        self.start_failures.clear();

        let registered = self.services.len();
        self.services.clear();
        self.is_running = false;
        self.start_time = None;

        tracing::debug!(
            cleared_services = registered,
            "Daemon state reset for shutdown"
        );
    }

    /// Reaps any children that have exited since the last call.
    ///
    /// The supervisor does not restart a crashed service — a crash is a bug
    /// the user needs to see, not a process to paper over with a restart
    /// loop. Instead, `poll` reaps the exited child, removes it from
    /// `children`, and returns its exit status so the caller can log it or
    /// surface it in the settings page.
    ///
    /// Call from the daemon's event loop (e.g. every few seconds).
    pub fn poll(&mut self) -> Vec<(RdeService, std::process::ExitStatus)> {
        let mut exited = Vec::new();
        let mut to_remove = Vec::new();

        for (service, child) in self.children.iter_mut() {
            match child.try_wait() {
                Ok(Some(status)) => {
                    exited.push((*service, status));
                    to_remove.push(*service);
                }
                Ok(None) => {}
                Err(error) => {
                    tracing::warn!(
                        service = service.bin_name(),
                        %error,
                        "failed to poll service"
                    );
                    to_remove.push(*service);
                }
            }
        }
        for service in to_remove {
            self.children.remove(&service);
        }
        exited
    }

    /// Whether the child process for `service` is still running.
    ///
    /// Returns `false` for a service that was never spawned (not installed,
    /// or failed to spawn) and for one that has exited since the last poll.
    /// A service can be alive without being registered over the socket, and
    /// registered without being alive (it was started by `systemd --user`,
    /// not by this supervisor).
    pub fn is_alive(&mut self, service: RdeService) -> bool {
        let Some(child) = self.children.get_mut(&service) else {
            return false;
        };
        match child.try_wait() {
            Ok(None) => true,
            Ok(Some(_)) => {
                self.children.remove(&service);
                false
            }
            Err(_) => false,
        }
    }

    /// Services detected as installed at startup.
    pub fn installed_rde_services(&self) -> &[RdeService] {
        &self.installed_rde_services
    }

    /// Services that failed to spawn in [`App::start`], with their reason.
    pub fn start_failures(&self) -> &HashMap<RdeService, String> {
        &self.start_failures
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

/// Spawns one RDE service as a detached child.
///
/// Inherits stdout/stderr so the service's logs go to the session journal.
/// `stdin` is null so a service that reads stdin gets EOF instead of blocking
/// on a terminal that isn't there.
fn spawn_service(service: RdeService) -> Result<Child, String> {
    Command::new(service.bin_name())
        .stdin(Stdio::null())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .spawn()
        .map_err(|error| format!("failed to spawn {}: {error}", service.bin_name()))
}

/// Sends `SIGTERM` to `child`, waits up to three seconds for it to exit, then
/// `SIGKILL`s and reaps it.
///
/// The child is always reaped, so a service that ignores `SIGTERM` doesn't
/// become a zombie.
fn terminate_child(service: RdeService, mut child: Child) {
    #[cfg(unix)]
    {
        // `Child::kill` sends SIGKILL. For a clean shutdown, send SIGTERM
        // first via `libc` or `nix`. The `nix` dependency is already pulled
        // in for other signal handling; if not, `libc::kill` works too.
        let pid = nix::unistd::Pid::from_raw(child.id() as i32);
        let _ = nix::sys::signal::kill(pid, nix::sys::signal::Signal::SIGTERM);
    }
    #[cfg(not(unix))]
    {
        let _ = child.kill();
    }

    let deadline = Instant::now() + std::time::Duration::from_secs(3);
    while Instant::now() < deadline {
        match child.try_wait() {
            Ok(Some(_)) => break,
            Ok(None) => std::thread::sleep(std::time::Duration::from_millis(50)),
            Err(_) => break,
        }
    }

    // Whatever state the child is in, kill and reap it.
    let _ = child.kill();
    let _ = child.wait();
    tracing::info!(service = service.bin_name(), "stopped service");
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
    fn start_is_idempotent() {
        let mut app = App::new();
        app.start();
        let first_uptime = app.uptime_secs();

        app.start(); // no-op
        assert!(app.is_running());
        assert!(app.uptime_secs().is_some());
        // Uptime keeps counting; the second start doesn't reset it.
        assert!(app.uptime_secs().unwrap() >= first_uptime.unwrap_or(0));
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
