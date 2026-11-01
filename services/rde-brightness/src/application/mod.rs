//! # Application Layer
//!
//! Glues the domain rules into a stateful service that executes brightness
//! commands. Async runtimes remain confined to the infrastructure layer.

pub mod commands;
pub mod service;

/// Failure returned by the application layer.
pub type ApplicationError = anyhow::Error;

/// Result type used by the application layer.
pub type ApplicationResult<T> = Result<T, ApplicationError>;

pub use commands::BrightnessCommand;
pub use service::{BrightnessService, BrightnessSnapshot};
