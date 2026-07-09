use rde_core::errors::ipc::IpcErrorCode;
use serde::{Deserialize, Serialize};

/// Top-level envelope sent in both directions.
#[derive(Serialize, Deserialize, Debug)]
pub enum Request {
    /// First message a service sends after connecting.
    Register {
        service_name: String, // e.g. "rde-volume"
        pid: u32,
        version: String, // service's own crate version
    },
    /// Response to a daemon HealthCheck.
    Alive,
    /// Service is shutting down cleanly (e.g. after SIGTERM handled).
    Deregister { service_name: String },
}

#[derive(Serialize, Deserialize, Debug)]
pub enum Event {
    /// Periodic liveness probe. Service must reply with Request::Alive
    /// within `health_check_timeout_ms` (config, default 2000ms).
    HealthCheck,
    /// Ask the service to reload its config from disk without restarting.
    ReloadConfig,
    /// Ask the service to persist state and exit gracefully.
    Shutdown { grace_period_ms: u64 },
}

/// Acknowledgement / result envelope for a Request.
#[derive(Serialize, Deserialize, Debug)]
pub enum Response {
    Ok,
    Error { code: IpcErrorCode, message: String },
}
