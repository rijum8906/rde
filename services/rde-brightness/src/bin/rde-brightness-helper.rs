//! # Brightness Helper Binary
//!
//! Privileged helper binary for writing brightness values to sysfs.
//! Used when the service process doesn't have direct write permissions to sysfs backlight files.
//!
//! ## Purpose
//! Runs with escalated privileges via `pkexec` to write brightness values to protected sysfs files.
//! Called by the brightness service when direct sysfs writes fail.
//!
//! ## Usage
//! ```bash
//! pkexec /usr/bin/rde-brightness-helper <brightness_file_path> <brightness_value>
//! ```
//!
//! ## Arguments
//! 1. `brightness_file_path`: Full path to sysfs brightness file (e.g., `/sys/class/backlight/intel_backlight/brightness`)
//! 2. `brightness_value`: Raw brightness value to write (integer string)
//!
//! ## Error Handling
//! - Prints error message to stderr if write fails
//! - Returns non-zero exit code on errors
//! - No logging framework (kept minimal for privilege escalation safety)
//!
//! ## Security Considerations
//! - Must be installed as root-owned binary with appropriate polkit rules
//! - Validates arguments exist before processing
//! - No complex logic to minimize attack surface
//! - Should be in /usr/bin/ or /usr/local/bin/ for access control
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

fn main() {
    // Get all the arguments passed to the helper
    let args: Vec<String> = std::env::args().collect();

    // Validate we have the required arguments
    if args.len() < 3 {
        eprintln!(
            "Usage: {} <brightness_file_path> <brightness_value>",
            args.first().unwrap_or(&"rde-brightness-helper".to_string())
        );
        std::process::exit(1);
    }

    // Extract the arguments
    let brightness_path = &args[1];
    let brightness_value = &args[2];

    // Write the brightness value to the sysfs file
    // Note: This runs with elevated privileges via pkexec
    if let Err(e) = std::fs::write(brightness_path, brightness_value) {
        eprintln!(
            "Failed to write brightness value '{}' to '{}': {}",
            brightness_value, brightness_path, e
        );
        std::process::exit(1);
    }
}
