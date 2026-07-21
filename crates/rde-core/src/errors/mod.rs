pub mod ipc;

// crates/rde-core/src/error.rs
use thiserror::Error;

use crate::errors::ipc::IpcError;

#[derive(Error, Debug)]
pub enum RdeError {
    // ============================================
    // Common Errors (General)
    // ============================================
    #[error("Not Found: {0}")]
    NotFound(String),

    // ============================================
    // System-Level Errors (OS, Hardware)
    // ============================================
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("System error: {0}")]
    System(String),

    #[error("Hardware not found: {0}")]
    HardwareNotFound(String),

    #[error("Hardware error: {0}")]
    Hardware(String),

    // ============================================
    // Configuration Errors
    // ============================================
    #[error("Configuration error: {0}")]
    Config(String),

    #[error("Configuration file not found: {0}")]
    ConfigNotFound(String),

    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),

    // ============================================
    // IPC Errors (Internal Communication)
    // ============================================
    #[error("IPC error: {0}")]
    Ipc(#[from] IpcError),

    #[error("Socket error: {0}")]
    Socket(String),

    // ============================================
    // D-Bus Errors (External Communication)
    // ============================================
    #[error("D-Bus error: {0}")]
    Dbus(#[from] zbus::Error),

    #[error("Zbus error: {0}")]
    Zbus(#[from] zbus::fdo::Error),

    #[error("D-Bus service not available: {0}")]
    DbusServiceUnavailable(String),

    // ============================================
    // Service Management Errors
    // ============================================
    #[error("Service error: {0}")]
    Service(String),

    #[error("Service not found: {0}")]
    ServiceNotFound(String),

    #[error("Service failed to start: {0}")]
    ServiceStartFailed(String),

    #[error("Service crashed: {0}")]
    ServiceCrashed(String),

    // ============================================
    // Runtime Errors
    // ============================================
    #[error("Runtime error: {0}")]
    Runtime(String),

    #[error("Internal error: {0}")]
    Internal(String),

    #[error("Not implemented: {0}")]
    NotImplemented(String),

    // ============================================
    // Permission Errors
    // ============================================
    #[error("Permission denied: {0}")]
    PermissionDenied(String),

    #[error("Policy error: {0}")]
    Policy(String),

    // ============================================
    // Invalid Value Errors
    // ============================================
    #[error("Invalid value: {0}")]
    InvalidValue(String),
}

// Custom Result type for library crates
pub type RdeResult<T> = std::result::Result<T, RdeError>;
