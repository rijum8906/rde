# rde-brightness

`rde-brightness` is a lightweight, asynchronous brightness management service written in Rust. It provides a system-wide D-Bus interface for controlling screen backlight brightness, supporting both raw values and percentage-based adjustments.

## 🚀 Features

- **D-Bus Interface**: Seamless inter-process communication via `org.rde.Brightness`.
- **Percentage & Raw Control**: Adjust brightness using either hardware-specific raw values or a universal 0-100% scale.
- **Hardware Integration**: Directly interacts with Linux backlight sysfs (`/sys/class/backlight`).
- **Secure Execution**: Uses a minimal setuid-capable helper or `pkexec` for writing to protected sysfs files.
- **Asynchronous Core**: Built on `tokio` and `zbus` for high performance and responsiveness.

## 🛠 Tech Stack

- **Language**: [Rust](https://www.rust-lang.org/)
- **D-Bus**: [zbus](https://github.com/dbus2/zbus)
- **Async Runtime**: [tokio](https://tokio.rs/)
- **Hardware Interaction**: Sysfs (`/sys/class/backlight`)

## 🏗 Project Structure

```text
src/
├── main.rs          # Service entry point and D-Bus server setup
├── lib.rs           # Crate modules declaration
├── brightness.rs    # Core Brightness logic and D-Bus interface
├── constants.rs     # System-wide constants and paths
└── bin/
    └── helper.rs    # Root-privileged helper for sysfs writes
```

## 📡 D-Bus API Reference

### Service Details
- **Bus Name**: `org.rde.Brightness`
- **Object Path**: `/org/rde/Brightness`
- **Interface**: `org.rde.Brightness`

### Properties
| Property | Type | Description |
| :--- | :--- | :--- |
| `Brightness` | `u16` | Current raw brightness value. |
| `BrightnessPercentage` | `u8` | Current brightness as a percentage (0-100). |
| `MaxBrightness` | `u16` | Maximum supported brightness value (Read-only). |

### Methods
- `increase_brightness(value: u16)`: Increases brightness by the specified raw value.
- `decrease_brightness(value: u16)`: Decreases brightness by the specified raw value.
- `increase_brightness_percentage(value: u8)`: Increases brightness by the specified percentage.
- `decrease_brightness_percentage(value: u8)`: Decreases brightness by the specified percentage.

## 🚦 Getting Started

### Prerequisites
- [Rust](https://www.rust-lang.org/tools/install) (stable)
- D-Bus (standard on most Linux distributions)
- `pkexec` (for privileged brightness writes)

### Building
```bash
cargo build --release
```

### Running
To start the brightness service:
```bash
cargo run --bin rde-brightness
```

## 🧪 Testing
The project includes unit tests for brightness calculations and logic.
```bash
cargo test
```

## 📄 License
This project is part of the `rde` ecosystem. Check individual files or the root repository for licensing information.
