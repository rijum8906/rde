//! Event notifications (server → client, unsolicited)

use super::types::{ServiceId, ServiceStatus};
use serde::{Deserialize, Serialize};

/// Server-sent events
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum Event {
    /// Service registered
    ServiceRegistered(ServiceRegisteredEvent),

    /// Service unregistered
    ServiceUnregistered(ServiceUnregisteredEvent),

    /// Service status changed
    ServiceStatusChanged(ServiceStatusChangedEvent),

    /// Server shutting down
    ServerShutdown(ServerShutdownEvent),

    /// Configuration reloaded
    ConfigReloaded(ConfigReloadedEvent),

    /// Health check
    HealthCheck,
}

/// Service registered event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceRegisteredEvent {
    pub service: ServiceId,
    pub version: String,
}

/// Service unregistered event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceUnregisteredEvent {
    pub service: ServiceId,
    pub reason: String,
}

/// Service status changed event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceStatusChangedEvent {
    pub service: ServiceId,
    pub old_status: ServiceStatus,
    pub new_status: ServiceStatus,
    pub message: Option<String>,
}

/// Server shutdown event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerShutdownEvent {
    pub reason: String,
    pub grace_period: u64, // seconds
}

/// Config reloaded event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigReloadedEvent {
    pub timestamp: u64,
    pub services_added: Vec<String>,
    pub services_removed: Vec<String>,
}
