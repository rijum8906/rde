pub mod handler;

use std::{
    process,
    sync::{Arc, OnceLock},
    time::Instant,
};

use futures_util::lock::Mutex;
use rde_core::{
    errors::{RdeError, RdeResult},
    logger::{LogLevel, Logger},
    utils::{ipc::get_socket_path, logger::init_log_dir},
};
use rde_ipc::{
    message::{Message, MessagePayload, RegisterRequest, ServiceRequest},
    socket::IpcClient,
};
use tokio::signal;
use tokio::sync::Mutex as TokioMutex;

use crate::{constants::MAX_SOCKET_CONN_RETRY_COUNT, dbus::iface::BrightnessInterface};

/// the main application for this service, implemented as a singleton
///
/// # SECURITY:
/// - Thread-safety is achieved by wrapping the global singleton state in a `Mutex`.
pub struct App {
    pub version: String,
    pub is_running: bool,
    pub start_time: Option<Instant>,

    /// if the service is connected to the daemon
    pub is_conneced: bool,

    /// the ipc client
    pub client: Arc<TokioMutex<Option<IpcClient>>>,

    interface: Option<BrightnessInterface>,
}

static APP_INSTANCE: OnceLock<Mutex<App>> = OnceLock::new();

impl App {
    fn new() -> RdeResult<Self> {
        // initialize the global Logger
        let base_log_dir = init_log_dir()?;
        let log_dir = base_log_dir.join("brightness");
        let logger = Logger::new(LogLevel::Info, log_dir, "brightness");
        logger.init()?;

        // create a new brightness service
        let brightness_interface = BrightnessInterface::new(logger)?;

        Ok(Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
            is_running: false,
            start_time: None,
            client: Arc::new(TokioMutex::new(None)),
            interface: Some(brightness_interface),
            is_conneced: false,
        })
    }

    pub fn global() -> &'static Mutex<App> {
        APP_INSTANCE.get_or_init(|| Mutex::new(App::new().unwrap()))
    }

    pub async fn run(&mut self) -> RdeResult<()> {
        tracing::info!("Starting Brightness Application...");

        let interface = self.interface.take().ok_or_else(|| {
            RdeError::Socket("BrightnessInterface has already been taken or run".to_string())
        })?;

        // build dbus connection and register the brightness interface
        let conn = zbus::connection::Builder::session()?
            .name("org.rde.Brightness")?
            .serve_at("/org/rde/Brightness", interface)?
            .build()
            .await
            .map_err(RdeError::Dbus)?;

        self.is_running = true;
        self.start_time = Some(Instant::now());

        // Spawn connection and supervisor monitoring loop asynchronously in a background task
        let client_clone = Arc::clone(&self.client);
        let version = self.version.clone();
        self.is_conneced = true;

        tokio::spawn(async move {
            let socket_path = match get_socket_path() {
                Ok(path) => path,
                Err(e) => {
                    tracing::error!("Failed to get UDS socket path: {}", e);
                    return;
                }
            };

            let mut connected_client = None;
            for i in 0..MAX_SOCKET_CONN_RETRY_COUNT {
                match IpcClient::connect(&socket_path).await {
                    Ok(c) => {
                        connected_client = Some(c);
                        break;
                    }
                    Err(e) => {
                        tracing::warn!(
                            "Failed to connect to daemon socket (attempt {}/{}): {}",
                            i + 1,
                            MAX_SOCKET_CONN_RETRY_COUNT,
                            e
                        );
                    }
                }
                tokio::time::sleep(std::time::Duration::from_millis(2000)).await;
            }

            if connected_client.is_none() {
                tracing::error!("Could not connect to daemon socket after retries");
                return;
            }

            let mut client = connected_client.unwrap();

            // register with the daemon
            let message = Message::new(MessagePayload::ServiceRequest(ServiceRequest::Register(
                RegisterRequest {
                    pid: process::id(),
                    name: "brightness".to_string(),
                    version,
                    capabilities: vec![],
                },
            )));

            if let Err(e) = client.send(&message).await {
                tracing::error!("Failed to send registration request: {}", e);
                return;
            }

            // Save the successfully connected client in the shared mutex
            {
                let mut client_guard = client_clone.lock().await;
                *client_guard = Some(client);
            }

            // Process incoming supervisor socket messages (liveness checks, events)
            use crate::app::handler::Handler;
            let mut handler = Handler::new("brightness");
            loop {
                // Lock client only to call recv()
                let msg_res = {
                    let mut client_guard = client_clone.lock().await;
                    if let Some(ref mut c) = *client_guard {
                        c.recv().await
                    } else {
                        break;
                    }
                };

                match msg_res {
                    Ok(msg) => {
                        // Lock client to process the message and send responses
                        let mut client_guard = client_clone.lock().await;
                        if let Some(ref mut c) = *client_guard {
                            let res = handler.handle_message(msg, c).await;
                            if let Err(e) = res {
                                tracing::error!("Error handling supervisor message: {}", e);
                                break;
                            }
                        }
                    }
                    Err(e) => {
                        tracing::error!("UDS connection to daemon supervisor lost: {}", e);
                        break;
                    }
                }
            }
        });

        // start the D-Bus service
        tracing::info!("Brightness D-Bus service started successfully on org.rde.Brightness");
        conn.request_name("org.rde.Brightness").await?;

        // Wait for Ctrl+C to exit
        tracing::info!("Waiting for Ctrl+C signal...");
        signal::ctrl_c().await?;

        tracing::info!("Ctrl+C signal received. Shutting down Brightness Application...");
        self.shutdown().await;

        Ok(())
    }

    pub async fn shutdown(&mut self) {
        tracing::info!("Performing App cleanup...");

        if self.is_conneced {
            let lock_res = self.client.try_lock();
            if let Ok(mut guard) = lock_res {
                if let Err(e) = guard.take().unwrap().close().await {
                    tracing::warn!("Failed to close ipc client: {}", e);
                }
                *guard = None;
            }
        }

        self.is_running = false;
        self.start_time = None;
        tracing::info!("Brightness service shut down cleanly.");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_brightness_app_lifecycle() {
        let backlight_exists = std::path::Path::new("/sys/class/backlight/").exists();
        let app_res = App::new();

        if backlight_exists {
            assert!(
                app_res.is_ok(),
                "Expected App::new to succeed on host with backlight"
            );
            let mut app = app_res.unwrap();

            assert!(!app.is_running, "App should not be running initially");
            assert!(
                app.start_time.is_none(),
                "Start time should be None initially"
            );

            // Test shutdown state transitions
            app.shutdown().await;
            assert!(!app.is_running, "App should be stopped after shutdown");
            assert!(
                app.start_time.is_none(),
                "Start time should be None after shutdown"
            );
        } else {
            assert!(
                app_res.is_err(),
                "Expected App::new to fail with ConfigNotFound in test/CI environment without backlight"
            );
        }
    }
}
