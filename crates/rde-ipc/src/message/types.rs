//! Shared types used across messages

use serde::{Deserialize, Serialize};
use std::time::SystemTime;

/// Service identification
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ServiceId {
    pub name: String,
    pub pid: u32,
}

/// Service status
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ServiceStatus {
    Starting,
    Running,
    Stopped,
    Unhealthy,
    Dead,
}

/// Service information (full)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceInfo {
    pub id: ServiceId,
    pub status: ServiceStatus,
    pub uptime: Option<SystemTime>,
    pub restart_count: u32,
    pub version: String,
}

/// Health status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthStatus {
    pub healthy: bool,
    pub last_heartbeat: SystemTime,
    pub message: Option<String>,
}

/// Error details
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorDetails {
    pub code: u32,
    pub message: String,
    pub details: Option<String>,
}
