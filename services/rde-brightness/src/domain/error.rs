//! # Domain Errors
//!
//! Error type shared by display detection and brightness actuation.

use std::io;

use thiserror::Error;

/// Failures produced by the domain layer.
#[derive(Debug, Error)]
pub enum DomainError {
    /// A brightness percentage outside the supported 0-100 range.
    #[error("invalid brightness percentage {0}, expected 0-100")]
    InvalidPercentage(u8),

    /// `wlr-randr` reported no enabled output.
    #[error("no active display was detected")]
    NoActiveDisplay,

    /// The requested output is not active.
    #[error("display '{0}' is not active")]
    DisplayNotFound(String),

    /// No backlight device exists under the sysfs root.
    #[error("no internal backlight device found in {0}")]
    BacklightNotFound(String),

    /// A sysfs file or DRM symlink could not be read.
    #[error("failed to read {path}: {source}")]
    Read {
        /// Path that could not be read.
        path: String,
        /// Underlying I/O failure.
        #[source]
        source: io::Error,
    },

    /// A sysfs file could not be written.
    #[error("failed to write {path}: {source}")]
    Write {
        /// Path that could not be written.
        path: String,
        /// Underlying I/O failure.
        #[source]
        source: io::Error,
    },

    /// A value was read but could not be parsed.
    #[error("could not parse {what}: {reason}")]
    Parse {
        /// Value that could not be parsed.
        what: String,
        /// Parser failure description.
        reason: String,
    },

    /// An external command could not be started.
    #[error("failed to run '{command}': {source}")]
    Command {
        /// Command line that could not be started.
        command: String,
        /// Underlying I/O failure.
        #[source]
        source: io::Error,
    },

    /// An external command exited unsuccessfully.
    #[error("'{command}' failed with status {status}: {stderr}")]
    CommandFailed {
        /// Command line that failed.
        command: String,
        /// Exit status reported by the process.
        status: String,
        /// Captured standard error.
        stderr: String,
    },

    /// The DRM DDC symlink does not point at an I2C adapter.
    #[error("could not resolve the I2C bus for display '{0}'")]
    DdcBusNotFound(String),
}
