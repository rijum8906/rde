use std::{
    path::PathBuf,
    sync::{Mutex, OnceLock},
};
use tracing::{Level, subscriber::set_global_default};
use tracing_subscriber::{EnvFilter, Registry, fmt, layer::SubscriberExt};

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
}

/// Global logger state
static LOGGER_STATE: OnceLock<LoggerState> = OnceLock::new();

type ReloadHandle = tracing_subscriber::reload::Handle<EnvFilter, Registry>;

/// Holds the logger state including the guard and reload handle
struct LoggerState {
    _guard: Mutex<Option<tracing_appender::non_blocking::WorkerGuard>>,
    reload_handle: ReloadHandle,
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
        let mut init_err = None;
        LOGGER_STATE.get_or_init(|| {
            // Create a filter that respects RUST_LOG environment variable
            // Default to configured level if not set
            let filter = EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new(self.level.as_str()));

            // Wrap filter in reloadable layer
            let (reload_filter, reload_handle) = tracing_subscriber::reload::Layer::new(filter);

            // Console subscriber with pretty formatting
            let console_subscriber = fmt::layer()
                .with_writer(std::io::stdout)
                .with_line_number(true)
                .with_thread_ids(false)
                .with_thread_names(false)
                .with_file(true)
                .with_target(true);

            // File subscriber with rotating daily logs
            let file_appender = tracing_appender::rolling::daily(&self.log_dir, &self.service_name);

            let (non_blocking, guard) = tracing_appender::non_blocking(file_appender);

            let file_subscriber = fmt::layer()
                .with_writer(non_blocking)
                .with_line_number(true)
                .with_file(true)
                .with_target(true)
                .with_ansi(false); // No colors in file

            // Combine both subscribers into a registry
            let subscriber = Registry::default()
                .with(reload_filter)
                .with(file_subscriber)
                .with(console_subscriber);

            // Set as global default
            if let Err(e) = set_global_default(subscriber) {
                init_err = Some(RdeError::Internal(format!(
                    "Failed to set global logger: {}",
                    e
                )));
            }

            // Store the guard and reload handle so they don't get dropped
            LoggerState {
                _guard: Mutex::new(Some(guard)),
                reload_handle,
            }
        });

        if let Some(err) = init_err {
            return Err(err);
        }

        Ok(())
    }

    /// Dynamically change the log level at runtime
    pub fn change_level(new_level: LogLevel) -> RdeResult<()> {
        if let Some(state) = LOGGER_STATE.get() {
            let filter = EnvFilter::new(new_level.as_str());
            state
                .reload_handle
                .modify(|old_filter| *old_filter = filter)
                .map_err(|e| RdeError::Internal(format!("Failed to reload log level: {}", e)))?;
            Ok(())
        } else {
            Err(RdeError::Internal("Logger not initialized".to_string()))
        }
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
    fn test_logger_functionality() -> RdeResult<()> {
        // Create a temporary directory for logs
        let temp_dir = tempdir()?;
        let log_dir = PathBuf::from(temp_dir.path());

        // Initialize logger with DEBUG level
        let logger = Logger::new(LogLevel::Debug, log_dir.clone(), "test-log".to_string());
        logger.init()?;

        // Helper to wait for expected content to be flushed to the file
        let read_with_retry = |path: &std::path::Path, expected: &str| -> String {
            let start = std::time::Instant::now();
            while start.elapsed() < std::time::Duration::from_secs(2) {
                if let Ok(contents) = std::fs::read_to_string(path)
                    && contents.contains(expected)
                {
                    return contents;
                }
                std::thread::sleep(std::time::Duration::from_millis(10));
            }
            std::fs::read_to_string(path).unwrap_or_default()
        };

        // 1. Test basic logging at DEBUG level
        info!("Testing logger initialization");
        debug!("This is a debug message");
        warn!("This is a warning");
        error!("This is an error");

        // Verify log file exists
        assert!(logger.log_dir.exists(), "Log file should exist");

        // Read and verify log content
        let file = logger.log_dir.join(format!(
            "{}.{:04}-{:02}-{:02}",
            logger.service_name,
            chrono::Local::now().year(),
            chrono::Local::now().month(),
            chrono::Local::now().day()
        ));
        let contents = read_with_retry(&file, "This is an error");

        // Check that our messages are in the log
        assert!(contents.contains("Testing logger initialization"));
        assert!(contents.contains("This is a debug message"));
        assert!(contents.contains("This is a warning"));
        assert!(contents.contains("This is an error"));

        // Clear log file contents for next phase
        std::fs::write(&file, "")?;

        // 2. Test dynamic log level change to Warn
        Logger::change_level(LogLevel::Warn)?;
        info!("DYNAMIC_TEST: This INFO should not appear");
        warn!("DYNAMIC_TEST: This WARN should appear");

        let contents = read_with_retry(&file, "DYNAMIC_TEST: This WARN should appear");
        assert!(!contents.contains("This INFO should not appear"));
        assert!(contents.contains("DYNAMIC_TEST: This WARN should appear"));

        // Clear log file contents
        std::fs::write(&file, "")?;

        // 3. Test dynamic log level change to Info
        Logger::change_level(LogLevel::Info)?;
        trace!("DYNAMIC_TEST: This TRACE should not appear");
        debug!("DYNAMIC_TEST: This DEBUG should not appear");
        info!("DYNAMIC_TEST: This INFO should now appear");

        let contents = read_with_retry(&file, "DYNAMIC_TEST: This INFO should now appear");
        assert!(!contents.contains("This TRACE should not appear"));
        assert!(!contents.contains("This DEBUG should not appear"));
        assert!(contents.contains("DYNAMIC_TEST: This INFO should now appear"));

        Ok(())
    }
}
