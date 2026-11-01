//! # Brightness Hardware Control
//!
//! Reads and writes brightness through sysfs backlights and DDC/CI monitors.
//! All hardware access in the service lives here. Writes are performed directly
//! by the service process, which must be in the `video` group to own the
//! backlight files.

use std::{
    fs, io,
    path::{Path, PathBuf},
    process::Command,
};

use tracing::{info, warn};

use super::error::DomainError;

/// Root of the kernel backlight class.
pub const BACKLIGHT_ROOT: &str = "/sys/class/backlight";

/// Preferred backlight devices, in priority order.
pub const PREFERRED_BACKLIGHTS: &[&str] = &["intel_backlight", "amdgpu_bl0"];

/// File holding the current raw brightness value.
pub const BRIGHTNESS_FILE: &str = "brightness";

/// File holding the maximum raw brightness value.
pub const MAX_BRIGHTNESS_FILE: &str = "max_brightness";

/// Root of the DRM connector class.
pub const DRM_ROOT: &str = "/sys/class/drm";

/// DDC/CI utility used for external monitors.
pub const DDCUTIL_BINARY: &str = "ddcutil";

/// VCP code for luminance.
pub const BRIGHTNESS_VCP: &str = "10";

/// A brightness value expressed on its hardware scale.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BrightnessLevel {
    /// Current raw value.
    pub raw: u32,
    /// Maximum raw value.
    pub max: u32,
}

impl BrightnessLevel {
    /// Creates a level, clamping `raw` to `max`.
    pub fn new(raw: u32, max: u32) -> Self {
        Self {
            raw: raw.min(max),
            max,
        }
    }

    /// Builds a level from a percentage on a 0-100 scale.
    pub fn from_percent(percent: u8) -> Self {
        Self {
            raw: u32::from(percent),
            max: 100,
        }
    }

    /// Returns the raw value as whole percent (0-100).
    pub fn percent(&self) -> u8 {
        if self.max == 0 {
            return 0;
        }

        ((u64::from(self.raw) * 100) / u64::from(self.max)) as u8
    }

    /// Converts a percentage into the raw value for `max`.
    pub fn raw_for_percent(percent: u8, max: u32) -> u32 {
        if max == 0 {
            return 0;
        }

        (u32::from(percent) * max / 100).min(max)
    }
}

/// Validates that a percentage is inside the D-Bus contract.
///
/// # Errors
/// Returns [`DomainError::InvalidPercentage`] for values above 100.
pub fn validate_percent(percent: u8) -> Result<(), DomainError> {
    if percent > 100 {
        return Err(DomainError::InvalidPercentage(percent));
    }

    Ok(())
}

/// Sets the brightness of a display, routing by connector name.
///
/// # Routing
/// - `DP`, `HDMI`, and `DVI` outputs use DDC/CI through `ddcutil`
/// - every other output (`eDP`, `LVDS`, `DSI`, or the internal fallback) uses
///   the sysfs backlight
///
/// # Parameters
/// - `output_name`: connector name, e.g. `eDP-1` or `DP-2`
/// - `percentage`: target brightness percentage (0-100)
///
/// # Errors
/// Returns a human-readable message when the percentage is invalid, the
/// display cannot be resolved, or the hardware write fails.
pub fn set_brightness(output_name: &str, percentage: u8) -> Result<(), String> {
    validate_percent(percentage).map_err(|error| error.to_string())?;

    if is_external_output(output_name) {
        set_external_brightness(output_name, percentage).map_err(|error| error.to_string())
    } else {
        set_internal_brightness(percentage).map_err(|error| error.to_string())
    }
}

/// Returns whether a connector is driven over an external cable.
///
/// DP, HDMI, and DVI outputs are DDC/CI monitors; `eDP` is deliberately not
/// matched because its name starts with `E`.
///
/// # Returns
/// `true` for external connectors, `false` for internal panels and unknown
/// outputs, which fall back to the sysfs backlight.
pub fn is_external_output(output_name: &str) -> bool {
    let name = output_name.trim().to_ascii_uppercase();

    name.starts_with("DP") || name.starts_with("HDMI") || name.starts_with("DVI")
}

/// Resolves the preferred internal backlight device.
///
/// # Errors
/// Returns [`DomainError::BacklightNotFound`] when the sysfs root is missing or
/// holds no device.
pub fn internal_backlight_path() -> Result<PathBuf, DomainError> {
    resolve_backlight_path(Path::new(BACKLIGHT_ROOT))
}

/// Resolves a backlight device under `root`.
///
/// # Returns
/// The preferred device (`intel_backlight`, then `amdgpu_bl0`, then an NVIDIA
/// device) when present, otherwise the first device in sorted order.
///
/// # Errors
/// Returns [`DomainError::BacklightNotFound`] when `root` does not exist or has
/// no device directories, and [`DomainError::Read`] for other read failures.
pub fn resolve_backlight_path(root: &Path) -> Result<PathBuf, DomainError> {
    // Step 1: Prefer known drivers so the same device is always used.
    for candidate in PREFERRED_BACKLIGHTS {
        let path = root.join(candidate);
        if path.is_dir() {
            info!(device = %path.display(), "Using preferred backlight device");
            return Ok(path);
        }
    }

    // Step 2: Collect the remaining devices in a deterministic order.
    let entries = match fs::read_dir(root) {
        Ok(entries) => entries,
        Err(error) if error.kind() == io::ErrorKind::NotFound => {
            return Err(DomainError::BacklightNotFound(root.display().to_string()));
        }
        Err(source) => {
            return Err(DomainError::Read {
                path: root.display().to_string(),
                source,
            });
        }
    };

    let mut devices = entries
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| path.is_dir())
        .collect::<Vec<_>>();
    devices.sort();

    // Step 3: NVIDIA drivers expose names such as `nvidia_0`; prefer those over
    // an arbitrary ACPI device. Then take the first remaining device.
    let nvidia = devices.iter().find(|path| {
        path.file_name()
            .and_then(|name| name.to_str())
            .is_some_and(|name| name.starts_with("nvidia"))
    });
    let selected = nvidia.cloned().or_else(|| devices.into_iter().next());

    match selected {
        Some(path) => {
            info!(device = %path.display(), "Using backlight device");
            Ok(path)
        }
        None => Err(DomainError::BacklightNotFound(root.display().to_string())),
    }
}

/// Reads the current level of the internal backlight.
///
/// # Errors
/// Returns [`DomainError::BacklightNotFound`] when no device exists and
/// [`DomainError::Read`] / [`DomainError::Parse`] when the sysfs files are
/// unreadable or malformed.
pub fn internal_brightness() -> Result<BrightnessLevel, DomainError> {
    let device = internal_backlight_path()?;
    read_internal_level(&device)
}

/// Reads the level of a specific backlight device directory.
///
/// # Errors
/// Returns [`DomainError::Read`] when a sysfs file cannot be read and
/// [`DomainError::Parse`] when its content is not a number.
pub fn read_internal_level(device: &Path) -> Result<BrightnessLevel, DomainError> {
    let max = read_number(&device.join(MAX_BRIGHTNESS_FILE))?;
    let raw = read_number(&device.join(BRIGHTNESS_FILE))?;

    Ok(BrightnessLevel::new(raw, max))
}

/// Sets the internal backlight to a percentage.
///
/// # Workflow
/// 1. Validate the percentage and resolve the backlight device
/// 2. Convert the percentage to the device scale
/// 3. Write the sysfs file directly as the service user
///
/// # Errors
/// Returns [`DomainError::InvalidPercentage`], [`DomainError::BacklightNotFound`],
/// [`DomainError::BacklightPermission`], or [`DomainError::Write`].
pub fn set_internal_brightness(percent: u8) -> Result<(), DomainError> {
    validate_percent(percent)?;
    let device = internal_backlight_path()?;

    write_internal_level(&device, percent)
}

/// Sets a specific backlight device directory to a percentage.
///
/// # Errors
/// Propagates the failures documented on [`set_internal_brightness`].
pub fn write_internal_level(device: &Path, percent: u8) -> Result<(), DomainError> {
    validate_percent(percent)?;

    // Step 1: Scale the percentage onto the device maximum.
    let max = read_number(&device.join(MAX_BRIGHTNESS_FILE))?;
    let raw = BrightnessLevel::raw_for_percent(percent, max);
    let target = device.join(BRIGHTNESS_FILE);

    // Step 2: Write the sysfs file directly. The service must be able to open
    // it for writing, normally because its user is in the `video` group.
    match fs::write(&target, raw.to_string()) {
        Ok(()) => {}
        Err(source) if source.kind() == io::ErrorKind::PermissionDenied => {
            warn!(
                %source,
                path = %target.display(),
                percent,
                "Permission denied writing the backlight; add the service user to the 'video' group"
            );
            return Err(DomainError::BacklightPermission {
                path: target.display().to_string(),
                source,
            });
        }
        Err(source) => {
            warn!(
                %source,
                path = %target.display(),
                percent,
                "Failed to write the backlight"
            );
            return Err(DomainError::Write {
                path: target.display().to_string(),
                source,
            });
        }
    }

    info!(
        percent,
        raw,
        max,
        path = %target.display(),
        "Applied internal brightness"
    );

    Ok(())
}

/// Reads the level of an external monitor over DDC/CI.
///
/// # Errors
/// Returns [`DomainError::DdcBusNotFound`] when the DRM symlink cannot be
/// resolved, and the command/parse errors from `ddcutil`.
pub fn external_brightness(output_name: &str) -> Result<BrightnessLevel, DomainError> {
    let bus = ddc_bus(output_name)?;
    let command = format!("{DDCUTIL_BINARY} --bus {bus} getvcp {BRIGHTNESS_VCP}");
    let output = Command::new(DDCUTIL_BINARY)
        .arg("--bus")
        .arg(bus.to_string())
        .arg("getvcp")
        .arg(BRIGHTNESS_VCP)
        .arg("--brief")
        .output()
        .map_err(|source| DomainError::Command {
            command: command.clone(),
            source,
        })?;

    if !output.status.success() {
        return Err(DomainError::CommandFailed {
            command,
            status: output.status.to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }

    parse_getvcp_brief(&String::from_utf8_lossy(&output.stdout)).ok_or_else(|| DomainError::Parse {
        what: format!("brightness of '{output_name}'"),
        reason: "unexpected ddcutil output".to_string(),
    })
}

/// Sets an external monitor to a percentage over DDC/CI.
///
/// # Errors
/// Returns [`DomainError::InvalidPercentage`], [`DomainError::DdcBusNotFound`],
/// or the command error from `ddcutil`.
pub fn set_external_brightness(output_name: &str, percent: u8) -> Result<(), DomainError> {
    validate_percent(percent)?;
    let bus = ddc_bus(output_name)?;
    let command = format!("{DDCUTIL_BINARY} --bus {bus} setvcp {BRIGHTNESS_VCP} {percent}");
    let output = Command::new(DDCUTIL_BINARY)
        .arg("--bus")
        .arg(bus.to_string())
        .arg("setvcp")
        .arg(BRIGHTNESS_VCP)
        .arg(percent.to_string())
        .output()
        .map_err(|source| DomainError::Command {
            command: command.clone(),
            source,
        })?;

    if !output.status.success() {
        return Err(DomainError::CommandFailed {
            command,
            status: output.status.to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }

    info!(
        output = output_name,
        percent, bus, "Applied external brightness"
    );
    Ok(())
}

/// Resolves the I2C bus number for a DRM connector.
///
/// # Workflow
/// 1. Read the `ddc` symlink at `/sys/class/drm/card0-<output>/ddc`
/// 2. Take the trailing `i2c-<n>` component of the link target
///
/// # Errors
/// Returns [`DomainError::DdcBusNotFound`] when the symlink is missing or does
/// not point at an I2C adapter.
pub fn ddc_bus(output_name: &str) -> Result<u16, DomainError> {
    let link = Path::new(DRM_ROOT)
        .join(format!("card0-{output_name}"))
        .join("ddc");

    let target = fs::read_link(&link).map_err(|source| match source.kind() {
        io::ErrorKind::NotFound => DomainError::DdcBusNotFound(output_name.to_string()),
        _ => DomainError::Read {
            path: link.display().to_string(),
            source,
        },
    })?;

    parse_i2c_bus(&target).ok_or_else(|| DomainError::DdcBusNotFound(output_name.to_string()))
}

/// Extracts an `i2c-<n>` bus number from a DRM DDC symlink target.
///
/// # Returns
/// `None` when no path component names an I2C adapter.
pub fn parse_i2c_bus(target: &Path) -> Option<u16> {
    target.components().rev().find_map(|component| {
        let name = component.as_os_str().to_str()?;
        name.strip_prefix("i2c-")?.parse::<u16>().ok()
    })
}

/// Parses the `--brief` output of `ddcutil getvcp 10`.
///
/// # Returns
/// The current and maximum luminance from a line such as `VCP 10 C 50 100`.
pub fn parse_getvcp_brief(output: &str) -> Option<BrightnessLevel> {
    let tokens = output.split_whitespace().collect::<Vec<_>>();

    // Step 1: Require the VCP header and both luminance values.
    if tokens.len() < 5 || !tokens[0].eq_ignore_ascii_case("VCP") {
        return None;
    }

    // Step 2: Parse `current` and `max`, then clamp the current value.
    let raw = tokens[3].parse::<u32>().ok()?;
    let max = tokens[4].parse::<u32>().ok()?;

    Some(BrightnessLevel::new(raw, max))
}

/// Reads a single unsigned integer from a sysfs file.
fn read_number(path: &Path) -> Result<u32, DomainError> {
    let content = fs::read_to_string(path).map_err(|source| DomainError::Read {
        path: path.display().to_string(),
        source,
    })?;

    content
        .trim()
        .parse::<u32>()
        .map_err(|error| DomainError::Parse {
            what: path.display().to_string(),
            reason: error.to_string(),
        })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn temp_device() -> tempfile::TempDir {
        tempfile::tempdir().expect("temporary backlight device")
    }

    #[test]
    fn percent_conversion_rounds_down_and_clamps() {
        assert_eq!(BrightnessLevel::new(50, 4096).percent(), 1);
        assert_eq!(BrightnessLevel::new(2048, 4096).percent(), 50);
        assert_eq!(BrightnessLevel::new(4096, 4096).percent(), 100);
        assert_eq!(BrightnessLevel::new(9000, 4096).percent(), 100);
        assert_eq!(BrightnessLevel::new(5, 0).percent(), 0);
    }

    #[test]
    fn raw_conversion_uses_the_device_scale() {
        assert_eq!(BrightnessLevel::raw_for_percent(50, 255), 127);
        assert_eq!(BrightnessLevel::raw_for_percent(100, 255), 255);
        assert_eq!(BrightnessLevel::raw_for_percent(0, 255), 0);
        assert_eq!(BrightnessLevel::raw_for_percent(50, 0), 0);
    }

    #[test]
    fn invalid_percent_is_rejected() {
        assert!(validate_percent(101).is_err());
        assert!(validate_percent(100).is_ok());
    }

    #[test]
    fn preferred_backlight_wins_over_alphabetical_order() {
        let root = tempfile::tempdir().expect("temporary backlight root");
        fs::create_dir_all(root.path().join("acpi_video0")).expect("acpi device");
        fs::create_dir_all(root.path().join("amdgpu_bl0")).expect("amd device");
        fs::create_dir_all(root.path().join("intel_backlight")).expect("intel device");

        let device = resolve_backlight_path(root.path()).expect("preferred device");
        assert_eq!(device, root.path().join("intel_backlight"));
    }

    #[test]
    fn nvidia_driver_is_preferred_over_other_fallbacks() {
        let root = tempfile::tempdir().expect("temporary backlight root");
        fs::create_dir_all(root.path().join("acpi_video0")).expect("acpi device");
        fs::create_dir_all(root.path().join("nvidia_0")).expect("nvidia device");

        let device = resolve_backlight_path(root.path()).expect("nvidia device");
        assert_eq!(device, root.path().join("nvidia_0"));
    }

    #[test]
    fn connector_names_route_to_the_right_backend() {
        for external in ["DP-1", "DP-2", "HDMI-A-1", "DVI-I-1", "hdmi-0"] {
            assert!(is_external_output(external), "{external} must use ddcutil");
        }

        for internal in ["eDP-1", "LVDS-1", "DSI-1", "internal", ""] {
            assert!(!is_external_output(internal), "{internal} must use sysfs");
        }
    }

    #[test]
    fn routing_rejects_invalid_percentages_before_hardware_access() {
        let error = set_brightness("DP-1", 101).expect_err("101% must be rejected");

        assert!(error.contains("invalid brightness percentage 101"));
    }

    #[test]
    fn unknown_driver_falls_back_to_first_device() {
        let root = tempfile::tempdir().expect("temporary backlight root");
        fs::create_dir_all(root.path().join("acpi_video1")).expect("first device");
        fs::create_dir_all(root.path().join("acpi_video0")).expect("second device");

        let device = resolve_backlight_path(root.path()).expect("fallback device");
        assert_eq!(device, root.path().join("acpi_video0"));
    }

    #[test]
    fn missing_and_empty_roots_report_no_backlight() {
        let root = tempfile::tempdir().expect("temporary backlight root");
        let missing = root.path().join("missing");

        assert!(matches!(
            resolve_backlight_path(&missing),
            Err(DomainError::BacklightNotFound(_))
        ));
        assert!(matches!(
            resolve_backlight_path(root.path()),
            Err(DomainError::BacklightNotFound(_))
        ));
    }

    #[test]
    fn internal_write_scales_to_max_brightness() {
        let root = temp_device();
        let device = root.path();
        fs::write(device.join(MAX_BRIGHTNESS_FILE), "255\n").expect("max brightness");
        fs::write(device.join(BRIGHTNESS_FILE), "10\n").expect("brightness");

        assert_eq!(read_internal_level(device).expect("current level").raw, 10);

        write_internal_level(device, 50).expect("write brightness");

        let raw = fs::read_to_string(device.join(BRIGHTNESS_FILE)).expect("read back brightness");
        assert_eq!(raw.trim(), "127");
    }

    #[test]
    fn internal_write_rejects_out_of_range_percent() {
        let root = temp_device();
        fs::write(root.path().join(MAX_BRIGHTNESS_FILE), "255\n").expect("max brightness");

        assert!(matches!(
            write_internal_level(root.path(), 150),
            Err(DomainError::InvalidPercentage(150))
        ));
    }

    #[test]
    fn i2c_bus_is_read_from_the_symlink_target() {
        assert_eq!(parse_i2c_bus(Path::new("../../../i2c-7")), Some(7));
        assert_eq!(
            parse_i2c_bus(Path::new("/sys/bus/i2c/devices/i2c-12")),
            Some(12)
        );
        assert_eq!(parse_i2c_bus(Path::new("../../../drm/card0")), None);
    }

    #[test]
    fn brief_getvcp_output_is_parsed() {
        assert_eq!(
            parse_getvcp_brief("VCP 10 C 50 100\n"),
            Some(BrightnessLevel { raw: 50, max: 100 })
        );
        assert_eq!(
            parse_getvcp_brief("VCP 10 C 255 100"),
            Some(BrightnessLevel { raw: 100, max: 100 })
        );
        assert!(parse_getvcp_brief("Display not found").is_none());
        assert!(parse_getvcp_brief("").is_none());
    }
}
