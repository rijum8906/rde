// ========================= SYSFS =========================
/// Default backlight sysfs path
pub const BACKLIGHT_SYSFS_PATH: &str = "/sys/class/backlight";

/// Default brightness file name
pub const BRIGHTNESS_FILE: &str = "brightness";

/// Default max brightness file name
pub const MAX_BRIGHTNESS_FILE: &str = "max_brightness";

// ========================= D-BUS =========================
/// D-Bus service name
pub const DBUS_SERVICE_NAME: &str = "org.rde.Brightness";

/// D-Bus object path
pub const DBUS_OBJECT_PATH: &str = "/org/rde/Brightness";

// ========================= COMMANDS =========================
///  Brightness helper command
pub const BRIGHTNESS_HELPER_COMMAND: &str = "/usr/lib/rde/rde-brightness-helper";
