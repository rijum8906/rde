//! # Display Detection
//!
//! Parses `wlr-randr` output and classifies connectors as internal (eDP, LVDS,
//! DSI) or external (DisplayPort, HDMI, DVI, and others).

use std::process::Command;

use tracing::{debug, warn};

use super::error::DomainError;

/// Binary used to enumerate Wayland outputs.
pub const WLR_RANDR_BINARY: &str = "wlr-randr";

/// An enabled Wayland output reported by `wlr-randr`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DisplayInfo {
    /// Connector name, e.g. `eDP-1` or `DP-2`.
    pub name: String,

    /// Human-readable description taken from the output header.
    pub description: String,

    /// Whether the connector drives the built-in panel.
    pub is_internal: bool,
}

impl DisplayInfo {
    /// Builds display information from a connector name alone.
    ///
    /// # Returns
    /// `None` when `name` is empty after trimming.
    pub fn from_connector(name: &str) -> Option<Self> {
        let name = name.trim();
        if name.is_empty() {
            return None;
        }

        Some(Self {
            name: name.to_string(),
            description: String::new(),
            is_internal: Self::is_internal_connector(name),
        })
    }

    /// Builds the fallback used when no output can be enumerated.
    ///
    /// # Returns
    /// A synthetic display that routes writes to the internal backlight.
    pub fn internal_fallback() -> Self {
        Self {
            name: "internal".to_string(),
            description: "Internal panel (fallback)".to_string(),
            is_internal: true,
        }
    }

    /// Returns whether a connector drives the built-in panel.
    ///
    /// Internal connectors are embedded DisplayPort (`eDP`), LVDS and DSI.
    /// Everything else, including `DP` and `HDMI`, is treated as external.
    pub fn is_internal_connector(name: &str) -> bool {
        let upper = name.trim().to_ascii_uppercase();

        // Step 1: Match the connector families that are soldered to the device.
        upper.starts_with("EDP") || upper.starts_with("LVDS") || upper.starts_with("DSI")
    }
}

/// Returns every enabled output reported by `wlr-randr`.
///
/// # Errors
/// Returns [`DomainError::Command`] when `wlr-randr` cannot be started,
/// [`DomainError::CommandFailed`] when it exits unsuccessfully, and
/// [`DomainError::NoActiveDisplay`] when no output is enabled.
pub fn active_displays() -> Result<Vec<DisplayInfo>, DomainError> {
    // Step 1: Ask the compositor for every output.
    let output =
        Command::new(WLR_RANDR_BINARY)
            .output()
            .map_err(|source| DomainError::Command {
                command: WLR_RANDR_BINARY.to_string(),
                source,
            })?;

    // Step 2: Reject a failed query instead of parsing partial output.
    if !output.status.success() {
        return Err(DomainError::CommandFailed {
            command: WLR_RANDR_BINARY.to_string(),
            status: output.status.to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }

    // Step 3: Parse stdout and require at least one enabled output.
    let displays = parse_wlr_randr_output(&String::from_utf8_lossy(&output.stdout));
    if displays.is_empty() {
        warn!("wlr-randr reported no enabled displays");
        return Err(DomainError::NoActiveDisplay);
    }

    debug!(count = displays.len(), "Detected active displays");
    Ok(displays)
}

/// Returns the first enabled output.
///
/// # Errors
/// Propagates the failures documented on [`active_displays`].
pub fn active_display() -> Result<DisplayInfo, DomainError> {
    active_displays()?
        .into_iter()
        .next()
        .ok_or(DomainError::NoActiveDisplay)
}

/// Parses `wlr-randr` output and keeps only enabled outputs.
///
/// Each output block starts with an unindented header such as
/// `eDP-1 "BOE 0x0A2B (eDP-1)"`; the block is kept when it contains
/// `Enabled: yes`.
///
/// # Returns
/// The enabled displays in the order reported by the compositor. An empty
/// vector means no output was enabled or the input had no output blocks.
pub fn parse_wlr_randr_output(output: &str) -> Vec<DisplayInfo> {
    let mut displays = Vec::new();
    let mut current: Option<DisplayInfo> = None;
    let mut enabled = false;

    for line in output.lines() {
        if line.trim().is_empty() {
            continue;
        }

        // Step 1: Indented lines carry block properties.
        if line.starts_with(char::is_whitespace) {
            if let Some(value) = line.trim().strip_prefix("Enabled:") {
                enabled = value.trim().eq_ignore_ascii_case("yes");
            }
            continue;
        }

        // Step 2: A new header flushes the previous block when it was enabled.
        if let Some(display) = current.take()
            && enabled
        {
            displays.push(display);
        }
        enabled = false;

        // Step 3: The header is `<name> "<description>"`.
        let mut parts = line.splitn(2, char::is_whitespace);
        let name = parts.next().unwrap_or_default().trim();
        let description = parts.next().unwrap_or_default().trim().trim_matches('"');

        if name.is_empty() {
            continue;
        }

        current = Some(DisplayInfo {
            name: name.to_string(),
            description: description.to_string(),
            is_internal: DisplayInfo::is_internal_connector(name),
        });
    }

    // Step 4: Flush the final block.
    if let Some(display) = current
        && enabled
    {
        displays.push(display);
    }

    displays
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r#"eDP-1 "BOE 0x0A2B (eDP-1)"
  Make: BOE
  Model: 0x0A2B
  Physical size: 344x194 mm
  Enabled: yes
  Modes:
    1920x1080 px, 60.000000 Hz (preferred, current)

DP-1 "Dell Inc. DELL U2419H (DP-1)"
  Make: Dell Inc.
  Model: DELL U2419H
  Physical size: 527x296 mm
  Enabled: no

HDMI-A-1 "Samsung Electric Company S24R35x (HDMI-A-1)"
  Enabled: yes
"#;

    #[test]
    fn parses_only_enabled_outputs() {
        let displays = parse_wlr_randr_output(SAMPLE);

        assert_eq!(displays.len(), 2);
        assert_eq!(displays[0].name, "eDP-1");
        assert!(displays[0].is_internal);
        assert_eq!(displays[0].description, "BOE 0x0A2B (eDP-1)");
        assert_eq!(displays[1].name, "HDMI-A-1");
        assert!(!displays[1].is_internal);
    }

    #[test]
    fn disabled_output_is_dropped() {
        let displays = parse_wlr_randr_output(SAMPLE);

        assert!(displays.iter().all(|display| display.name != "DP-1"));
    }

    #[test]
    fn empty_output_yields_no_displays() {
        assert!(parse_wlr_randr_output("").is_empty());
        assert!(parse_wlr_randr_output("noise\n").is_empty());
    }

    #[test]
    fn connector_classification_distinguishes_panels() {
        for internal in ["eDP-1", "LVDS-1", "DSI-1", "edp-2"] {
            assert!(
                DisplayInfo::is_internal_connector(internal),
                "{internal} must be internal"
            );
        }

        for external in ["DP-1", "HDMI-A-1", "DVI-I-1", "Unknown-1"] {
            assert!(
                !DisplayInfo::is_internal_connector(external),
                "{external} must be external"
            );
        }
    }

    #[test]
    fn blank_connector_is_rejected() {
        assert!(DisplayInfo::from_connector("   ").is_none());
        assert!(DisplayInfo::from_connector("DP-2").is_some_and(|display| !display.is_internal));
    }
}
