pub mod handler;

use std::{process, time::Instant};

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

use crate::dbus::iface::BrightnessInterface;

/// the main application for this service, implemented as a singleton
///
/// # SECURITY:
/// - Thread-safety is achieved by wrapping the global singleton state in a `Mutex`.
pub struct App {
    pub version: String,
    pub is_running: bool,
    pub start_time: Option<Instant>,

    interface: Option<BrightnessInterface>,
}

impl App {
    pub fn new() -> RdeResult<Self> {
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
            interface: Some(brightness_interface),
        })
    }

    pub async fn run(mut self) -> RdeResult<()> {
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

        // create a socket client
        let socket_path = get_socket_path()?;
        let mut client = IpcClient::connect(&socket_path).await?;
        let message = Message::new(MessagePayload::ServiceRequest(ServiceRequest::Register(
            RegisterRequest {
                pid: process::id(),
                name: "brightness".to_string(),
                version: self.version.clone(),
                capabilities: vec![],
            },
        )));
        client.send(&message).await?;

        // Spawn a background task to process incoming supervisor socket messages (liveness checks, events)
        tokio::spawn(async move {
            use crate::app::handler::Handler;
            let mut handler = Handler::new("brightness");
            loop {
                match client.recv().await {
                    Ok(msg) => {
                        if let Err(e) = handler.handle_message(msg, &mut client).await {
                            tracing::error!("Error handling supervisor message: {}", e);
                            break;
                        }
                    }
                    Err(e) => {
                        tracing::error!("UDS connection to daemon supervisor lost: {}", e);
                        break;
                    }
                }
            }
        });

        tracing::info!("Brightness D-Bus service started successfully on org.rde.Brightness");
        conn.request_name("org.rde.Brightness").await?;

        // Wait for Ctrl+C to exit
        tracing::info!("Waiting for Ctrl+C signal...");
        signal::ctrl_c().await?;

        tracing::info!("Ctrl+C signal received. Shutting down Brightness Application...");
        self.shutdown();

        Ok(())
    }

    pub fn shutdown(&mut self) {
        tracing::info!("Performing App cleanup...");
        self.is_running = false;
        self.start_time = None;
        tracing::info!("Brightness service shut down cleanly.");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_brightness_app_lifecycle() {
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
            app.shutdown();
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
