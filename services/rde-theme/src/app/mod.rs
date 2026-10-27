//! # Application Lifecycle
//!
//! Owns the service runtime: initialization, D-Bus service publication,
//! daemon supervision, and graceful shutdown.

mod thread;

use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Instant,
};

use rde_core::{
    errors::{RdeError, RdeResult},
    fs::rde_service_logs_dir,
    logger::{LogLevel, Logger},
};
use rde_ipc::thread::IpcThread;
use tokio::signal::unix::{SignalKind, signal};
use tokio_util::sync::CancellationToken;
use tracing::info;

use crate::{
    backend::{AdapterRegistry, GtkEmitter, QtAdapter},
    constants::{DBUS_SERVICE_NAME, SERVICE_NAME, SHUTDOWN_TIMEOUT},
    dbus::{
        PORTAL_OBJECT_PATH, PortalSettingsInterface, THEME_OBJECT_PATH, ThemeInterface,
        spawn_dbus_signal_broadcaster,
    },
    paths::{ThemePaths, xdg_config_home, xdg_data_home},
    service::ThemeService,
    theme_store::DiskThemeRepository,
};

/// Process-wide state for the theme service.
pub struct App {
    version: String,
    is_running: Arc<AtomicBool>,
    start_time: Instant,
    connected: Arc<AtomicBool>,
    service: Arc<ThemeService>,
    ipc_thread: Option<IpcThread>,
    shutdown_token: CancellationToken,
}

impl App {
    /// Initializes application logging, repository, and theme service.
    ///
    /// # Errors
    /// Returns [`RdeError`] if logging cannot be initialized or the repository fails.
    pub async fn new() -> RdeResult<Self> {
        // Step 1: Initialize logger
        let log_dir = rde_service_logs_dir(SERVICE_NAME)?;
        Logger::new(LogLevel::Debug, log_dir, SERVICE_NAME)
            .init()
            .map_err(|e| RdeError::Internal(e.to_string()))?;

        info!("Initializing RDE Theme Service...");

        // Step 2: Resolve standard XDG paths
        let paths = ThemePaths::resolve();

        // Step 3: Initialize disk repository
        let disk_repo = DiskThemeRepository::new(
            paths.data_themes_dir().to_path_buf(),
            paths.config_themes_dir().to_path_buf(),
            paths.cache_theme_dir().to_path_buf(),
        )
        .with_system_themes(paths.system_themes_dir().to_path_buf());

        // Step 4: Register the toolkit adapters
        let gtk_emitter = GtkEmitter::new(paths.cache_theme_dir().to_path_buf());
        // KDE reads `kdeglobals` from the XDG config root and looks color schemes
        // up under `color-schemes/` in the XDG data home, so the emitter targets
        // those directories instead of the rde theme subdirectories.
        let qt_emitter = QtAdapter::new(xdg_config_home(), xdg_data_home());

        let mut adapter_registry = AdapterRegistry::default();
        for adapter in [
            Box::new(gtk_emitter) as Box<dyn crate::backend::Adapter>,
            Box::new(qt_emitter),
        ] {
            let id = crate::domain::identity::AdapterId::new(adapter.name())
                .map_err(|e| RdeError::Internal(e.to_string()))?;
            adapter_registry.adapters.insert(id, adapter);
        }

        // Step 5: Startup theme service
        let service = ThemeService::startup(
            Arc::new(disk_repo),
            adapter_registry,
            paths.published_theme_file(),
            paths.settings_file(),
            paths.data_themes_dir().to_path_buf(),
        )
        .await
        .map_err(|e| RdeError::Internal(e.to_string()))?;

        let service = Arc::new(service);

        Ok(Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
            is_running: Arc::new(AtomicBool::new(false)),
            start_time: Instant::now(),
            connected: Arc::new(AtomicBool::new(false)),
            service,
            ipc_thread: None,
            shutdown_token: CancellationToken::new(),
        })
    }

    /// Runs the application event loop until termination is requested.
    ///
    /// # Errors
    /// Returns [`RdeError`] if D-Bus connection or signal registration fails.
    pub async fn run(&mut self) -> RdeResult<()> {
        self.is_running.store(true, Ordering::SeqCst);

        // Step 1: Start file change watcher
        self.service.start_watcher();

        // Step 2: Connect to session bus and export D-Bus interfaces
        let iface = ThemeInterface::new(self.service.clone());
        let portal = PortalSettingsInterface::new(self.service.clone());

        let connection = zbus::connection::Builder::session()
            .map_err(RdeError::Dbus)?
            .name(DBUS_SERVICE_NAME)
            .map_err(RdeError::Dbus)?
            .serve_at(THEME_OBJECT_PATH, iface)
            .map_err(RdeError::Dbus)?
            .serve_at(PORTAL_OBJECT_PATH, portal)
            .map_err(RdeError::Dbus)?
            .build()
            .await
            .map_err(RdeError::Dbus)?;

        info!(name = DBUS_SERVICE_NAME, "Registered D-Bus service");

        // Step 3: Connect broadcast channels to D-Bus signal emitter
        spawn_dbus_signal_broadcaster(connection, self.service.clone());

        // Step 4: Spawn supervisor IPC thread
        self.spawn_daemon_thread();

        // Step 5: Register Unix OS termination signals
        let mut sigint = signal(SignalKind::interrupt()).map_err(RdeError::Io)?;
        let mut sigterm = signal(SignalKind::terminate()).map_err(RdeError::Io)?;

        info!("RDE Theme Service is ready and serving requests");

        tokio::select! {
            _ = self.shutdown_token.cancelled() => {
                info!("Shutdown requested via internal cancellation token");
            }
            _ = sigint.recv() => {
                info!("Received SIGINT signal");
            }
            _ = sigterm.recv() => {
                info!("Received SIGTERM signal");
            }
        }

        self.shutdown().await;
        Ok(())
    }

    /// Performs graceful service shutdown.
    pub async fn shutdown(&mut self) {
        info!("Shutting down RDE Theme Service...");
        self.is_running.store(false, Ordering::SeqCst);

        if let Some(thread) = self.ipc_thread.take() {
            thread.cancellation_token.cancel();
            let _ = tokio::time::timeout(SHUTDOWN_TIMEOUT, thread.handle).await;
        }

        info!("RDE Theme Service shutdown complete");
    }

    /// Returns the uptime duration of the service.
    #[must_use]
    pub fn uptime(&self) -> std::time::Duration {
        self.start_time.elapsed()
    }
}
