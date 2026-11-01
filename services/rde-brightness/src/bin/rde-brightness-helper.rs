//! # Brightness Helper Binary
//!
//! Minimal root helper that applies a percentage to the preferred sysfs
//! backlight. `pkexec` starts it through the `org.rde.brightness.set` polkit
//! action; it deliberately does not link the service library.

use std::{
    fs,
    path::{Path, PathBuf},
    process,
};

/// Root of the kernel backlight class.
const BACKLIGHT_ROOT: &str = "/sys/class/backlight";

/// Preferred backlight devices, in priority order.
const PREFERRED_BACKLIGHTS: [&str; 2] = ["intel_backlight", "amdgpu_bl0"];

/// File holding the current raw brightness value.
const BRIGHTNESS_FILE: &str = "brightness";

/// File holding the maximum raw brightness value.
const MAX_BRIGHTNESS_FILE: &str = "max_brightness";

fn main() {
    if let Err(message) = run() {
        eprintln!("rde-brightness-helper: {message}");
        process::exit(1);
    }
}

/// Reads the percentage argument and writes it to the backlight device.
fn run() -> Result<(), String> {
    // Step 1: Parse and validate the single percentage argument.
    let args = std::env::args().collect::<Vec<_>>();
    let argument = args.get(1).ok_or_else(usage)?;
    let percent = argument
        .parse::<u8>()
        .map_err(|_| format!("'{argument}' is not a percentage"))?;

    if percent > 100 {
        return Err(format!("percentage {percent} is outside 0-100"));
    }

    // Step 2: Locate the same device the service prefers.
    let device = backlight_device()
        .ok_or_else(|| format!("no backlight device found in {BACKLIGHT_ROOT}"))?;

    // Step 3: Scale the percentage to the device maximum and write it.
    let max = read_number(&device.join(MAX_BRIGHTNESS_FILE))?;
    let raw = if max == 0 {
        0
    } else {
        (u32::from(percent) * max / 100).min(max)
    };
    let target = device.join(BRIGHTNESS_FILE);

    fs::write(&target, raw.to_string())
        .map_err(|error| format!("failed to write {}: {error}", target.display()))?;

    Ok(())
}

/// Returns the helper invocation line.
fn usage() -> String {
    "usage: rde-brightness-helper <percent 0-100>".to_string()
}

/// Resolves the preferred backlight device directory.
fn backlight_device() -> Option<PathBuf> {
    let root = Path::new(BACKLIGHT_ROOT);

    // Step 1: Prefer the drivers the service also prefers.
    for candidate in PREFERRED_BACKLIGHTS {
        let path = root.join(candidate);
        if path.is_dir() {
            return Some(path);
        }
    }

    // Step 2: Fall back to the first kernel device, matching the domain layer.
    let entries = fs::read_dir(root).ok()?;
    let mut devices = entries
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| path.is_dir())
        .collect::<Vec<_>>();
    devices.sort();

    devices.into_iter().next()
}

/// Reads a single unsigned integer from a sysfs file.
fn read_number(path: &Path) -> Result<u32, String> {
    let content = fs::read_to_string(path)
        .map_err(|error| format!("failed to read {}: {error}", path.display()))?;

    content
        .trim()
        .parse::<u32>()
        .map_err(|error| format!("failed to parse {}: {error}", path.display()))
}
