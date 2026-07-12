use std::sync::{Mutex, OnceLock};
use std::time::Instant;

use rde_ipc::message::{PROTOCOL_VERSION, ServiceInfo};

/// The main application state for the daemon, implemented as a singleton.
///
/// # SECURITY:
/// - Thread-safety is achieved by wrapping the global singleton state in a `Mutex`.
/// - Ensure locks are acquired for the shortest time possible to avoid blocking the async executor threads.
///
/// # IMPORTANT:
/// - This state must be initialized once by the main thread before starting the D-Bus interface or socket server.
///
/// # TODO:
/// - Persist registry/client states to disk periodically to recover from crashes.
/// - Read the RDE configuration file from `~/.config/rde/daemon.toml` at application startup
///   to bootstrap and manage configured services.
pub struct App {
    /// daemon app version
    pub version: String,

    /// indicates if the application is running
    pub is_running: bool,

    /// the start time of the application
    pub start_time: Option<Instant>,

    /// list of registered clients
    pub clients: Vec<ServiceInfo>,
}

/// The global singleton instance of the App
static APP_INSTANCE: OnceLock<Mutex<App>> = OnceLock::new();

impl App {
    /// Get a reference to the global singleton instance of the App
    pub fn global() -> &'static Mutex<App> {
        APP_INSTANCE.get_or_init(|| {
            Mutex::new(App {
                version: env!("CARGO_PKG_VERSION").to_string(),
                is_running: false,
                start_time: None,
                clients: vec![],
            })
        })
    }

    /// Start the application
    pub fn start(&mut self) {
        self.is_running = true;
        self.start_time = Some(Instant::now());
        tracing::info!(
            "Rde Daemon started (version: {}) (protocol version: {})",
            self.version,
            PROTOCOL_VERSION
        );
    }

    /// Stop the application
    pub fn stop(&mut self) {
        self.is_running = false;
        self.start_time = None;
        tracing::info!("Application stopped");
    }

    /// Add a client to the registered list
    pub fn add_client(&mut self, client: ServiceInfo) {
        self.clients.retain(|c| c.id.name != client.id.name);
        self.clients.push(client.clone());
        tracing::info!(
            "Registered client: {} (PID: {})",
            client.id.name,
            client.id.pid
        );
    }

    /// Remove a client from the registered list by name
    pub fn remove_client(&mut self, name: &str) {
        let initial_len = self.clients.len();
        self.clients.retain(|c| c.id.name != name);
        if self.clients.len() < initial_len {
            tracing::info!("Deregistered client: {}", name);
        }
    }

    /// Get the elapsed uptime of the application in seconds
    pub fn uptime(&self) -> Option<u64> {
        self.start_time.map(|start| start.elapsed().as_secs())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rde_ipc::message::types::{ServiceId, ServiceStatus};

    #[test]
    fn test_app_singleton_lifecycle_and_clients() {
        let app_mutex = App::global();

        {
            let mut app = app_mutex.lock().unwrap();
            assert!(!app.is_running);
            assert!(app.uptime().is_none());

            // Start app
            app.start();
            assert!(app.is_running);
            assert!(app.uptime().is_some());
        }

        // Add a client
        let service = ServiceInfo {
            id: ServiceId {
                name: "test-daemon-service".to_string(),
                pid: 9999,
            },
            status: ServiceStatus::Running,
            uptime: None,
            restart_count: 0,
            version: "1.0.0".to_string(),
        };

        {
            let mut app = app_mutex.lock().unwrap();
            assert_eq!(app.clients.len(), 0);

            app.add_client(service);
            assert_eq!(app.clients.len(), 1);
            assert_eq!(app.clients[0].id.name, "test-daemon-service");
            assert_eq!(app.clients[0].id.pid, 9999);

            // Remove the client
            app.remove_client("test-daemon-service");
            assert_eq!(app.clients.len(), 0);

            // Stop app
            app.stop();
            assert!(!app.is_running);
            assert!(app.uptime().is_none());
        }
    }
}
