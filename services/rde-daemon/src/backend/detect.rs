use std::env;
use std::path::PathBuf;
use std::process::Command;

/// A first-party RDE service the settings app can talk to.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum RdeService {
    Brightness,
    Volume,
    Theme,
}

impl RdeService {
    /// Binary name on `PATH` (and at `/usr/bin/<name>`).
    pub fn bin_name(&self) -> &'static str {
        match self {
            RdeService::Brightness => "rde-brightness",
            RdeService::Volume => "rde-volume",
            RdeService::Theme => "rde-theme",
        }
    }

    /// Human name for the UI ("Brightness", "Volume", "Theme").
    pub fn display_name(&self) -> &'static str {
        match self {
            RdeService::Brightness => "Brightness",
            RdeService::Volume => "Volume",
            RdeService::Theme => "Theme",
        }
    }

    /// Every service, in the order the settings page should list them.
    pub const ALL: [RdeService; 3] = [
        RdeService::Brightness,
        RdeService::Volume,
        RdeService::Theme,
    ];
}

/// Returns the RDE services installed on this machine.
///
/// A service is "installed" if its binary can be found either at
/// `/usr/bin/<name>` (the system path, where a distro package installs it) or
/// anywhere on `PATH` (where a user-local install, a Nix profile, or a
/// development build puts it). The two checks are redundant on most systems —
/// `/usr/bin` is on `PATH` — but they differ on systems where `PATH` is
/// customized (Flatpak wrappers, sandboxes, `PATH` overrides), and the
/// settings page needs to work in all of them.
///
/// This does **not** check whether the service is *running*. A service can be
/// installed but its D-Bus name unclaimed (the daemon crashed, hasn't been
/// started, or the user disabled it). Pair this with [`is_running`] if the UI
/// needs to distinguish "installed" from "available".
pub fn detect_services() -> Vec<RdeService> {
    RdeService::ALL
        .into_iter()
        .filter(|service| is_installed(*service))
        .collect()
}

/// Whether the service's binary is installed.
///
/// Checks `/usr/bin/<name>` first (cheap, covers the distro-package case
/// without touching `PATH`), then falls back to scanning `PATH`. A binary
/// that exists but is not executable is treated as not installed — the
/// settings app can't run it, so it can't be used.
fn is_installed(service: RdeService) -> bool {
    let system_path = PathBuf::from("/usr/bin").join(service.bin_name());
    if is_executable(&system_path) {
        return true;
    }
    which(service.bin_name()).is_some()
}

/// Whether the service's D-Bus name is claimed on the session bus.
///
/// This is the check the settings page uses to decide between "installed"
/// and "installed and running": a service whose name isn't on the bus has
/// its card disabled with a "not running" subtitle, instead of failing when
/// the user clicks a control.
///
/// The D-Bus name is `<bin_name>` with dashes replaced by dots, in the
/// `org.rde.<Name>` namespace:
///   - `rde-brightness` → `org.rde.Brightness`
///   - `rde-volume`     → `org.rde.Volume`
///   - `rde-theme`      → `org.rde.Theme`
///
/// `busctl --user list` is used because it doesn't require a zbus
/// connection per call. If the settings app already has a zbus connection,
/// prefer `zbus::fdo::DBusProxy::name_has_owner` — it's faster and async.
pub fn is_running(service: RdeService) -> bool {
    let name = dbus_name(service);
    let output = Command::new("busctl")
        .args(["--user", "--no-pager", "--no-legend", "list"])
        .output();
    match output {
        Ok(out) if out.status.success() => {
            let stdout = String::from_utf8_lossy(&out.stdout);
            stdout
                .lines()
                .any(|line| line.split_whitespace().next() == Some(&name))
        }
        _ => false,
    }
}

/// D-Bus well-known name the service owns on the session bus.
fn dbus_name(service: RdeService) -> String {
    // `rde-brightness` → `org.rde.Brightness`
    let stem = service
        .bin_name()
        .strip_prefix("rde-")
        .unwrap_or(service.bin_name());
    format!("org.rde.{}", capitalize(stem))
}

fn capitalize(input: &str) -> String {
    let mut chars = input.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().chain(chars).collect(),
        None => String::new(),
    }
}

/// Resolves `name` against `PATH`, returning the first executable match.
///
/// Re-implements the `which` crate's core loop in ~15 lines so the settings
/// app doesn't need a dependency for one call. Handles the cases that matter:
/// empty `PATH` entries (some wrappers emit `::`), non-executable files, and
/// `PATH` entries that don't exist.
fn which(name: &str) -> Option<PathBuf> {
    let path = env::var_os("PATH")?;
    for dir in env::split_paths(&path) {
        if dir.as_os_str().is_empty() {
            continue;
        }
        let candidate = dir.join(name);
        if is_executable(&candidate) {
            return Some(candidate);
        }
    }
    None
}

/// Whether `path` points to a file the current user can execute.
#[cfg(unix)]
fn is_executable(path: &std::path::Path) -> bool {
    use std::os::unix::fs::PermissionsExt;
    std::fs::metadata(path)
        .map(|m| m.is_file() && (m.permissions().mode() & 0o111 != 0))
        .unwrap_or(false)
}

#[cfg(not(unix))]
fn is_executable(path: &std::path::Path) -> bool {
    std::fs::metadata(path)
        .map(|m| m.is_file())
        .unwrap_or(false)
}
