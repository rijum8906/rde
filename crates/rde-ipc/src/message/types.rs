//! Shared types used across messages

use bincode::{Decode, Encode};
use std::time::SystemTime;

/// Service identification
#[derive(Debug, Clone, PartialEq, Encode, Decode)]
pub struct ServiceId {
    pub name: String,
    pub pid: u32,
}

/// Service status
#[derive(Debug, Clone, PartialEq, Encode, Decode)]
pub enum ServiceStatus {
    Starting,
    Running,
    Stopped,
    Unhealthy,
    Dead,
}

/// Service information (full)
#[derive(Debug, Clone, Encode, Decode)]
pub struct ServiceInfo {
    pub id: ServiceId,
    pub status: ServiceStatus,
    pub uptime: Option<SystemTime>,
    pub restart_count: u32,
    pub version: String,
}

/// Health status
#[derive(Debug, Clone, Encode, Decode)]
pub struct HealthStatus {
    pub healthy: bool,
    pub last_heartbeat: SystemTime,
    pub message: Option<String>,
}

/// Error details
#[derive(Debug, Clone, Encode, Decode)]
pub struct ErrorDetails {
    pub code: u32,
    pub message: String,
    pub details: Option<String>,
}
