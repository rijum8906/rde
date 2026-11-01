//! # Brightness Service
//!
//! Routes [`BrightnessCommand`]s to the domain layer and tracks the active
//! display together with its last known brightness level.

use std::sync::Mutex;

use anyhow::anyhow;
use tracing::{debug, info, warn};

use super::commands::BrightnessCommand;
use crate::{
    application::ApplicationError,
    domain::{
        brightness::{self, BrightnessLevel},
        display::{self, DisplayInfo},
        error::DomainError,
    },
};

/// Runtime state owned by the service.
#[derive(Debug)]
struct ServiceState {
    /// Display the last command targeted, when one has been resolved.
    display: Option<DisplayInfo>,

    /// Last brightness level known for `display`.
    level: BrightnessLevel,
}

/// Read-only view of the service state handed to the D-Bus layer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BrightnessSnapshot {
    /// Active connector name, when one has been resolved.
    pub display: Option<String>,

    /// Last known percentage (0-100).
    pub percent: u8,

    /// Last known raw value.
    pub raw: u32,

    /// Scale used by `raw`.
    pub max: u32,
}

/// Stateful brightness service.
#[derive(Debug)]
pub struct BrightnessService {
    /// Display and level cache protected against concurrent D-Bus calls.
    state: Mutex<ServiceState>,
}

impl Default for BrightnessService {
    fn default() -> Self {
        Self::new()
    }
}

impl BrightnessService {
    /// Builds the service and snapshots the current display.
    ///
    /// Detection failures are logged rather than fatal, so a session without
    /// `wlr-randr` can still drive the internal backlight.
    pub fn new() -> Self {
        let mut state = ServiceState {
            display: None,
            level: BrightnessLevel::new(0, 0),
        };

        // Step 1: Ask the domain layer for the active display.
        match display::active_display() {
            Ok(active) => {
                // Step 2: Snapshot its current level for immediate property reads.
                match read_level(&active) {
                    Ok(level) => state.level = level,
                    Err(error) => {
                        warn!(%error, display = %active.name, "Could not read the current brightness");
                    }
                }

                info!(
                    display = %active.name,
                    internal = active.is_internal,
                    "Active display detected"
                );
                state.display = Some(active);
            }
            Err(error) => {
                // Step 3: Without a wlroots compositor, start from the internal
                // backlight so property reads are accurate from the first call.
                if brightness::internal_backlight_path().is_ok() {
                    let fallback = DisplayInfo::internal_fallback();
                    match read_level(&fallback) {
                        Ok(level) => state.level = level,
                        Err(error) => {
                            warn!(%error, "Could not read the internal brightness");
                        }
                    }
                    state.display = Some(fallback);
                    warn!(%error, "No active display detected, using the internal backlight");
                } else {
                    warn!(
                        %error,
                        "No active display detected, brightness will be resolved per request"
                    );
                }
            }
        }

        Self {
            state: Mutex::new(state),
        }
    }

    /// Applies a command to the current or requested display.
    ///
    /// # Parameters
    /// - `command`: intent delivered by the D-Bus layer
    ///
    /// # Workflow
    /// 1. Lock the service state for the whole transaction
    /// 2. Resolve the target display through the domain layer
    /// 3. Apply the absolute or relative percentage to the matching backend
    /// 4. Record the resulting level and display
    ///
    /// # Errors
    /// Returns an error when the state lock is poisoned, the requested display
    /// is unknown, the percentage is invalid, or the hardware write fails.
    pub fn execute(&self, command: BrightnessCommand) -> Result<(), ApplicationError> {
        // Step 1: Serialise state updates across D-Bus property and method calls.
        let mut state = self
            .state
            .lock()
            .map_err(|_| anyhow!("brightness service state is poisoned"))?;

        match &command {
            BrightnessCommand::Set { output, percent } => {
                // Step 2: Validate before touching the display cache.
                brightness::validate_percent(*percent)?;
                let display = resolve_display(state.display.as_ref(), Some(output))?;

                // Step 3: Apply the absolute percentage and record the result.
                let level = apply(&display, *percent)?;
                state.display = Some(display);
                state.level = level;
                info!(percent = *percent, "Brightness set");
            }

            BrightnessCommand::Increase(_) | BrightnessCommand::Decrease(_) => {
                // Step 4: Follow the active display and read its real level.
                let display = resolve_display(state.display.as_ref(), None)?;
                let current = read_level(&display).unwrap_or_else(|error| {
                    let connector = display.name.as_str();
                    warn!(%error, %connector, "Falling back to the cached brightness");
                    state.level
                });
                let target = command
                    .adjusted_percent(current.percent())
                    .unwrap_or_else(|| current.percent());

                // Step 5: Apply the clamped result.
                let level = apply(&display, target)?;
                state.display = Some(display);
                state.level = level;
                info!(from = current.percent(), to = target, "Brightness adjusted");
            }
        }

        Ok(())
    }

    /// Returns the last known display and brightness.
    ///
    /// A poisoned lock reports a zeroed snapshot instead of panicking, so a
    /// failing property read cannot take down the D-Bus object.
    pub fn snapshot(&self) -> BrightnessSnapshot {
        match self.state.lock() {
            Ok(state) => BrightnessSnapshot {
                display: state.display.as_ref().map(|display| display.name.clone()),
                percent: state.level.percent(),
                raw: state.level.raw,
                max: state.level.max,
            },
            Err(_) => {
                warn!("Brightness state is poisoned, reporting a zero snapshot");
                BrightnessSnapshot {
                    display: None,
                    percent: 0,
                    raw: 0,
                    max: 0,
                }
            }
        }
    }
}

/// Resolves the display a command should target.
///
/// An empty request follows the active display. A named request reuses the
/// cached display when it matches, then refreshes the output list.
fn resolve_display(
    cached: Option<&DisplayInfo>,
    requested: Option<&str>,
) -> Result<DisplayInfo, ApplicationError> {
    // Step 1: No explicit output means "follow the active display".
    let Some(name) = requested.filter(|name| !name.trim().is_empty()) else {
        return active_display(cached);
    };
    let name = name.trim();

    // Step 2: Reuse the cached display when it matches.
    if let Some(display) = cached.filter(|display| display.name == name) {
        return Ok(display.clone());
    }

    // Step 3: Refresh the output list and look for the connector.
    match display::active_displays() {
        Ok(displays) => {
            let display = displays
                .into_iter()
                .find(|display| display.name == name)
                .ok_or_else(|| DomainError::DisplayNotFound(name.to_string()))?;
            Ok(display)
        }
        Err(error) => {
            // Step 4: Without wlr-randr, classify the connector by its name so
            // explicit internal and external outputs remain usable.
            warn!(
                %error,
                display = name,
                "Falling back to display classification by connector name"
            );
            DisplayInfo::from_connector(name).ok_or_else(|| {
                ApplicationError::from(DomainError::DisplayNotFound(name.to_string()))
            })
        }
    }
}

/// Returns the active display, degrading gracefully without detection.
fn active_display(cached: Option<&DisplayInfo>) -> Result<DisplayInfo, ApplicationError> {
    match display::active_display() {
        Ok(display) => Ok(display),
        Err(error) => {
            // Step 1: Keep the last known display across transient failures.
            if let Some(cached) = cached {
                warn!(
                    %error,
                    display = %cached.name,
                    "Display detection failed, keeping the cached display"
                );
                return Ok(cached.clone());
            }

            // Step 2: Fall back to the internal backlight when one exists.
            if brightness::internal_backlight_path().is_ok() {
                warn!(%error, "Display detection failed, using the internal backlight");
                return Ok(DisplayInfo::internal_fallback());
            }

            Err(error.into())
        }
    }
}

/// Reads the current level of a display.
fn read_level(display: &DisplayInfo) -> Result<BrightnessLevel, DomainError> {
    if brightness::is_external_output(&display.name) {
        brightness::external_brightness(&display.name)
    } else {
        brightness::internal_brightness()
    }
}

/// Applies a percentage to a display and reads the resulting level back.
fn apply(display: &DisplayInfo, percent: u8) -> Result<BrightnessLevel, ApplicationError> {
    // Step 1: Route by connector name so sysfs and DDC/CI stay separate.
    brightness::set_brightness(&display.name, percent).map_err(|error| anyhow::anyhow!(error))?;

    // Step 2: Read back so the reported state matches the hardware.
    match read_level(display) {
        Ok(level) => Ok(level),
        Err(error) => {
            let connector = display.name.as_str();
            warn!(%error, %connector, "Could not read the level after setting it");
            debug!(percent, "Reporting the requested percentage");
            Ok(BrightnessLevel::from_percent(percent))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Builds a service over fixed state without touching hardware.
    fn service_with(display: DisplayInfo, level: BrightnessLevel) -> BrightnessService {
        BrightnessService {
            state: Mutex::new(ServiceState {
                display: Some(display),
                level,
            }),
        }
    }

    #[test]
    fn snapshot_reports_the_cached_level() {
        let service = service_with(
            DisplayInfo::internal_fallback(),
            BrightnessLevel::new(75, 100),
        );

        let snapshot = service.snapshot();
        assert_eq!(snapshot.display.as_deref(), Some("internal"));
        assert_eq!(snapshot.percent, 75);
        assert_eq!(snapshot.raw, 75);
        assert_eq!(snapshot.max, 100);
    }

    #[test]
    fn set_rejects_out_of_range_percent_before_touching_hardware() {
        let service = service_with(
            DisplayInfo::internal_fallback(),
            BrightnessLevel::new(50, 100),
        );

        let error = service
            .execute(BrightnessCommand::Set {
                output: String::new(),
                percent: 101,
            })
            .expect_err("an out-of-range percentage must be rejected");

        assert!(error.to_string().contains("invalid brightness percentage"));
        assert_eq!(service.snapshot().percent, 50);
    }
}
