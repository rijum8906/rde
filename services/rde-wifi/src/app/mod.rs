use std::{
    sync::{Arc, OnceLock},
    time::Instant,
};

use futures_util::lock::Mutex;
use rde_core::errors::RdeResult;

use crate::ipc::handler::IpcHandler;

pub mod run;
pub mod shutdown;

/// the main application for this service, implemented as a singleton
///
pub struct Application {
    /// service app version
    /// literally the CARGO_PKG_VERSION
    version: String,

    /// if the service is running
    is_running: bool,

    /// the time the service started
    start_time: Option<Instant>,

    /// if the service is connected to the daemon
    is_conneced: bool,

    /// the ipc hanlder, if it's connected with ipc
    handler: Arc<Mutex<Option<IpcHandler>>>,
}

static APP_INSTANCE: OnceLock<Mutex<Application>> = OnceLock::new();

impl Application {
    pub fn new() -> RdeResult<Self> {
        // Initialize the global Logger
        let log_dir = rde_core::fs::rde_service_logs_dir("wifi")?;
        let logger =
            rde_core::logger::Logger::new(rde_core::logger::LogLevel::Info, log_dir, "wifi");
        logger.init()?;

        let version = env!("CARGO_PKG_VERSION").to_string();

        Ok(Self {
            version,
            is_running: false,
            start_time: None,
            is_conneced: false,
            handler: Arc::new(Mutex::new(None)),
        })
    }

    pub async fn global() -> &'static Mutex<Self> {
        APP_INSTANCE.get_or_init(|| Mutex::new(Application::new().unwrap()))
    }

    pub fn version(&self) -> &str {
        &self.version
    }

    pub fn is_running(&self) -> bool {
        self.is_running
    }

    pub fn start_time(&self) -> Option<Instant> {
        self.start_time
    }

    pub fn is_conneced(&self) -> bool {
        self.is_conneced
    }
}
