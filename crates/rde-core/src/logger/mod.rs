use std::{
    path::PathBuf,
    sync::{Mutex, OnceLock},
};

use tracing::{Level, subscriber::set_global_default};
use tracing_subscriber::{EnvFilter, Layer, Registry, fmt, layer::SubscriberExt};

use crate::errors::{RdeError, RdeResult};

#[derive(Clone, Copy, Debug)]
pub enum LogLevel {
    Debug,
    Info,
    Warn,
    Error,
}

impl LogLevel {
    pub fn as_str(&self) -> &'static str {
        match self {
            LogLevel::Debug => "debug",
            LogLevel::Info => "info",
            LogLevel::Warn => "warn",
            LogLevel::Error => "error",
        }
    }

    pub fn as_tracing_level(&self) -> Level {
        match self {
            LogLevel::Debug => Level::DEBUG,
            LogLevel::Info => Level::INFO,
            LogLevel::Warn => Level::WARN,
            LogLevel::Error => Level::ERROR,
        }
    }
}

#[derive(Debug)]
pub struct Logger {
    pub log_dir: PathBuf,
    pub level: Level,
    pub service_name: String,
    // private
    // console_logger:
}

/// Global logger state
static LOGGER_STATE: OnceLock<LoggerState> = OnceLock::new();

/// Holds the logger state including the guard
struct LoggerState {
    _guard: Mutex<Option<tracing_appender::non_blocking::WorkerGuard>>,
}

impl Logger {
    pub fn new(level: LogLevel, log_dir: PathBuf, service_name: String) -> Self {
        Self {
            log_dir,
            level: level.as_tracing_level(),
            service_name,
        }
    }

    pub fn init(&self) -> RdeResult<()> {
        // ============================================
        // 1. Create log directory if it doesn't exist
        // ============================================
        let log_path = std::path::Path::new(&self.log_dir);
        if !log_path.exists() {
            std::fs::create_dir_all(log_path).map_err(RdeError::Io)?;
        }

        // ============================================
        // 2. Initialize logger (only once)
        // ============================================
        let _ = LOGGER_STATE.get_or_init(|| {
            // Create a filter that respects RUST_LOG environment variable
            // Default to configured level if not set
            let filter = EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new(self.level.as_str()));

            // Console subscriber with pretty formatting
            let console_subscriber = fmt::layer()
                .with_writer(std::io::stdout)
                .with_line_number(true)
                .with_thread_ids(false)
                .with_thread_names(false)
                .with_file(true)
                .with_target(true)
                .with_filter(filter.clone());

            // File subscriber with rotating daily logs
            let file_appender = tracing_appender::rolling::daily(&self.log_dir, &self.service_name);

            let (non_blocking, guard) = tracing_appender::non_blocking(file_appender);

            let file_subscriber = fmt::layer()
                .with_writer(non_blocking)
                .with_line_number(true)
                .with_file(true)
                .with_target(true)
                .with_ansi(false) // No colors in file
                .with_filter(filter.clone());

            // Combine both subscribers into a registry
            let subscriber = Registry::default()
                .with(file_subscriber)
                .with(console_subscriber);

            // Set as global default
            set_global_default(subscriber).expect("Failed to set global logger");

            // Store the guard so it doesn't get dropped
            LoggerState {
                _guard: Mutex::new(Some(guard)),
            }
        });

        Ok(())
    }
}

// ============================================
// Tests
// ============================================

#[cfg(test)]
mod tests {

    use super::*;
    use chrono::Datelike;
    use tempfile::tempdir;
    use tracing::{debug, error, info, trace, warn};

    #[test]
    fn test_logger_initialization() -> RdeResult<()> {
        // Create a temporary directory for logs
        let temp_dir = tempdir()?;
        let log_dir = PathBuf::from(temp_dir.path());

        // Initialize logger
        let logger = Logger::new(LogLevel::Debug, log_dir.clone(), "test-log".to_string());
        logger.init()?;

        // Test logging
        info!("Testing logger initialization");
        debug!("This is a debug message");
        warn!("This is a warning");
        error!("This is an error");

        // Verify log file exists
        assert!(logger.log_dir.exists(), "Log file should exist");

        // Read and verify log content
        // find the file named {test.log.year-month-day}
        // the month and day should be 02 or 05 like this
        let file = logger.log_dir.join(format!(
            "{}.{:04}-{:02}-{:02}", // gives a padding of 0
            logger.service_name,
            chrono::Local::now().year(),
            chrono::Local::now().month(),
            chrono::Local::now().day()
        ));
        let contents = std::fs::read_to_string(file)?;

        // Check that our messages are in the log
        assert!(contents.contains("Testing logger initialization"));
        assert!(contents.contains("This is a debug message"));
        assert!(contents.contains("This is a warning"));
        assert!(contents.contains("This is an error"));

        Ok(())
    }

    #[test]
    fn test_different_log_levels() -> RdeResult<()> {
        let temp_dir = tempdir()?;
        let log_dir = PathBuf::from(temp_dir.path());

        // Test with INFO level
        let logger = Logger::new(LogLevel::Info, log_dir.clone(), "info.log".to_string());
        logger.init()?;

        trace!("This TRACE should NOT appear");
        debug!("This DEBUG should NOT appear");
        info!("This INFO should appear");
        warn!("This WARN should appear");
        error!("This ERROR should appear");

        let log_file = logger.log_dir.join(format!(
            "{}.{:04}-{:02}-{:02}", // gives a padding of 0
            logger.service_name,
            chrono::Local::now().year(),
            chrono::Local::now().month(),
            chrono::Local::now().day()
        ));
        let contents = std::fs::read_to_string(log_file)?;

        assert!(!contents.contains("TRACE"));
        assert!(!contents.contains("DEBUG"));
        assert!(contents.contains("INFO"));
        assert!(contents.contains("WARN"));
        assert!(contents.contains("ERROR"));

        Ok(())
    }

    #[test]
    fn test_env_filter_override() -> RdeResult<()> {
        // This test shows how RUST_LOG can override the default level
        // Run with: RUST_LOG=debug cargo test -- --nocapture

        let temp_dir = tempdir()?;
        let log_dir = PathBuf::from(temp_dir.path());

        let logger = Logger::new(LogLevel::Info, log_dir, "env.log".to_string());
        logger.init()?;

        // These will only appear if RUST_LOG is set to debug or lower
        debug!("This debug message depends on RUST_LOG");
        info!("This info message always appears");

        Ok(())
    }
}
