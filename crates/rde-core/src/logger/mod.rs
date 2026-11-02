//! # Shared Logging Facade
//!
//! Installs the process-wide `tracing` subscriber used by every RDE service and
//! applies the level policy from `docs/logging-guide.md`.

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

/// Maps a service name to the `tracing` target its crate records under.
///
/// Crate targets use underscores, so `rde-volume` becomes `rde_volume`. Names
/// that are not already prefixed with `rde_` (such as the daemon's `daemon`) are
/// prefixed here so the directive always matches the service's own events.
///
/// # Parameters
/// - `service_name`: name the service registered with, e.g. `rde-volume`
///
/// # Returns
/// The crate target, e.g. `rde_volume`
fn crate_target(service_name: &str) -> String {
    let normalized: String = service_name
        .chars()
        .map(|character| if character == '-' { '_' } else { character })
        .collect();

    if normalized.starts_with("rde_") {
        normalized
    } else {
        format!("rde_{normalized}")
    }
}

/// Builds the [`EnvFilter`] directive for an explicit crate level.
///
/// The service's own crate is recorded at `own_level`, while every other crate
/// is capped: third-party crates (zbus, hyper, tower, …) stay at `warn` in debug
/// builds and `error` in release builds so their chatter never floods the log.
/// `rde_core` is always included at `own_level` because the filesystem and logger
/// helpers it provides log on behalf of whichever service called them.
///
/// # Parameters
/// - `own_level`: level the service's own crate records at
/// - `service_name`: name of the service the logger is installed for
///
/// # Returns
/// An [`EnvFilter`] directive string, e.g. `warn,rde_volume=debug,rde_core=debug`
fn filter_directive(own_level: &str, service_name: &str) -> String {
    // Step 1: Cap every other crate.
    let third_party_level = if cfg!(debug_assertions) {
        "warn"
    } else {
        "error"
    };

    // Step 2: Emit the base directive followed by the crate-specific overrides.
    let target = crate_target(service_name);
    if target == "rde_core" {
        format!("{third_party_level},{target}={own_level}")
    } else {
        format!("{third_party_level},{target}={own_level},rde_core={own_level}")
    }
}

/// Returns the filter directive used when `RUST_LOG` is not set.
///
/// Two rules come from `docs/logging-guide.md`:
///
/// 1. `error`, `warn` and `info` are recorded in every build. `info` is reserved
///    for lifecycle events, so a released service still reports starting,
///    registering with the daemon, and shutting down.
/// 2. `debug` and `trace` are only recorded in debug builds: a released service
///    must not write per-operation diagnostics into a user's log files.
///
/// # Parameters
/// - `configured`: level requested by the service
/// - `service_name`: name of the service the logger is installed for
///
/// # Returns
/// An [`EnvFilter`] directive string, e.g. `warn,rde_volume=debug,rde_core=debug`
fn default_filter(configured: Level, service_name: &str) -> String {
    // Step 1: Resolve the level the service's own crate records at.
    let own_level = if cfg!(debug_assertions) {
        match configured {
            Level::ERROR => "error",
            Level::WARN => "warn",
            // INFO is escalated to `debug` while developing so diagnostics are
            // visible without editing code.
            Level::INFO | Level::DEBUG => "debug",
            Level::TRACE => "trace",
        }
    } else {
        match configured {
            Level::ERROR => "error",
            Level::WARN => "warn",
            // Release builds stop at `info`, whatever the service asked for.
            Level::INFO | Level::DEBUG | Level::TRACE => "info",
        }
    };

    // Step 2: Expand the resolved level into the crate-scoped directive.
    filter_directive(own_level, service_name)
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
    /// Crate target the installed filter was scoped to.
    target: String,
}

impl Logger {
    pub fn new(level: LogLevel, log_dir: PathBuf, service_name: &str) -> Self {
        Self {
            log_dir,
            level: level.as_tracing_level(),
            service_name: service_name.to_string(),
        }
    }

    /// Installs the global subscriber for this service.
    ///
    /// Writes to stdout and to a daily rotated file under [`Logger::log_dir`].
    /// Only the first call has an effect; later calls return successfully
    /// without touching the already installed subscriber.
    ///
    /// # Parameters
    /// - `is_release_mode`: hides file/line metadata when `true`
    ///
    /// # Errors
    /// Returns [`RdeError`] when the log directory cannot be created or the
    /// global subscriber is already occupied by another logger.
    pub fn init(&self, is_release_mode: bool) -> RdeResult<()> {
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
            // Step 1: Respect `RUST_LOG`, otherwise apply the documented
            // build-aware, crate-scoped default from `docs/logging-guide.md`.
            let filter = EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new(default_filter(self.level, &self.service_name)));

            // Wrap filter in reloadable layer
            let (reload_filter, reload_handle) =
                tracing_subscriber::reload::Layer::new(filter.clone());

            // Console subscriber with pretty formatting
            let console_subscriber = fmt::layer()
                .with_writer(std::io::stdout)
                .with_line_number(!is_release_mode)
                .with_thread_ids(false)
                .with_thread_names(false)
                .with_file(true)
                .with_target(true);

            // File subscriber with rotating daily logs
            let file_appender = tracing_appender::rolling::daily(&self.log_dir, &self.service_name);

            let (non_blocking, guard) = tracing_appender::non_blocking(file_appender);

            // The reloadable filter above already scopes every layer, so the
            // file layer only needs to disable ANSI colours.
            let file_subscriber = fmt::layer()
                .with_writer(non_blocking)
                .with_line_number(!is_release_mode)
                .with_file(true)
                .with_target(true)
                .with_ansi(false);

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

            // Store the guard, reload handle and crate target so they survive
            // for the lifetime of the process.
            LoggerState {
                _guard: Mutex::new(Some(guard)),
                reload_handle,
                target: crate_target(&self.service_name),
            }
        });

        if let Some(err) = init_err {
            return Err(err);
        }

        Ok(())
    }

    /// Dynamically change the log level at runtime.
    ///
    /// The new level keeps the crate-scoped policy: the service's own crate is
    /// filtered at `new_level` while third-party crates stay capped.
    ///
    /// # Errors
    /// Returns [`RdeError`] when the logger has not been initialised or the
    /// reload handle rejects the new filter.
    pub fn change_level(new_level: LogLevel) -> RdeResult<()> {
        if let Some(state) = LOGGER_STATE.get() {
            // A runtime change is applied literally: asking for `Info` silences
            // `debug` even in a debug build, which is how an operator quiets a
            // verbose session.
            let filter = EnvFilter::new(filter_directive(new_level.as_str(), &state.target));
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
    fn default_filter_hides_debug_outside_debug_builds() {
        // A service asking for the default level gets diagnostics only while
        // developing, and never a more verbose filter than the build allows.
        if cfg!(debug_assertions) {
            assert_eq!(
                default_filter(Level::INFO, "rde-volume"),
                "warn,rde_volume=debug,rde_core=debug"
            );
            assert_eq!(
                default_filter(Level::DEBUG, "rde-volume"),
                "warn,rde_volume=debug,rde_core=debug"
            );
            assert_eq!(
                default_filter(Level::TRACE, "rde-volume"),
                "warn,rde_volume=trace,rde_core=trace"
            );
        } else {
            assert_eq!(
                default_filter(Level::INFO, "rde-volume"),
                "error,rde_volume=info,rde_core=info"
            );
            assert_eq!(
                default_filter(Level::DEBUG, "rde-volume"),
                "error,rde_volume=info,rde_core=info"
            );
            assert_eq!(
                default_filter(Level::TRACE, "rde-volume"),
                "error,rde_volume=info,rde_core=info"
            );
        }

        // Error and warning records survive in every build.
        assert!(default_filter(Level::WARN, "rde-volume").contains("rde_volume=warn"));
        assert!(default_filter(Level::ERROR, "rde-volume").contains("rde_volume=error"));
    }

    #[test]
    fn crate_target_matches_the_crate_name() {
        // Crate targets use underscores, and the daemon is prefixed so its own
        // events are always matched by the directive.
        assert_eq!(crate_target("rde-volume"), "rde_volume");
        assert_eq!(crate_target("rde_volume"), "rde_volume");
        assert_eq!(crate_target("daemon"), "rde_daemon");
    }

    #[test]
    fn test_logger_functionality() -> RdeResult<()> {
        // Create a temporary directory for logs
        let temp_dir = tempdir()?;
        let log_dir = PathBuf::from(temp_dir.path());

        // Initialize logger with DEBUG level
        let logger = Logger::new(LogLevel::Debug, log_dir.clone(), "test-log");
        logger.init(false)?;

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
            chrono::Utc::now().year(),
            chrono::Utc::now().month(),
            chrono::Utc::now().day()
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
