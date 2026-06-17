# rde-theme

`rde-theme` is a lightweight, asynchronous theme management service written in Rust. It provides a system-wide D-Bus interface for managing application themes, supporting dynamic switching between light and dark modes, and persistent theme storage.

## 🚀 Features

- **D-Bus Interface**: Seamless inter-process communication via `org.rde.Theme`.
- **Light/Dark Mode Support**: Built-in support for theme modes with automatic state management.
- **Persistent Storage**: Themes are stored as JSON files in a dedicated storage directory.
- **Dynamic Updates**: Switch themes and modes on the fly with signal notification for consumers.
- **Asynchronous Core**: Built on `tokio` and `zbus` for high performance and responsiveness.

## 🛠 Tech Stack

- **Language**: [Rust](https://www.rust-lang.org/)
- **D-Bus**: [zbus](https://github.com/dbus2/zbus)
- **Async Runtime**: [tokio](https://tokio.rs/)
- **Serialization**: [serde](https://serde.rs/) / [serde_json](https://github.com/serde-rs/json)

## 🏗 Project Structure

```text
src/
├── main.rs          # Service entry point and D-Bus server setup
├── lib.rs           # Crate modules declaration
├── dbus.rs          # D-Bus interface implementation and logic
├── theme.rs         # Core Theme data structure
├── models.rs        # Shared data models (Enums, ThemeFiles)
├── defaults.rs      # Default theme configurations
├── constants.rs     # System-wide constants and paths
└── utils.rs         # Helper functions for storage and naming
```

## 📡 D-Bus API Reference

### Service Details
- **Bus Name**: `org.rde.Theme`
- **Object Path**: `/org/rde/Theme`
- **Interface**: `org.rde.Theme`

### Properties
| Property | Type | Description |
| :--- | :--- | :--- |
| `mode` | `String` | Current mode (`light` or `dark`). |
| `current_theme` | `Struct` | The active theme configuration object. |

### Methods
- `create_theme(theme: Theme)`: Registers a new theme to the storage.
- `list_themes() -> HashSet<String>`: Returns all available theme identifiers.
- `refresh_themes_list()`: Reloads themes from the storage disk.
- `set_accent(color: String)`: (WIP) Sets the system accent color.

## 🚦 Getting Started

### Prerequisites
- [Rust](https://www.rust-lang.org/tools/install) (stable)
- D-Bus (standard on most Linux distributions)

### Building
```bash
cargo build --release
```

### Running
To start the theme service:
```bash
cargo run
```

To run in **test mode** (uses separate storage):
```bash
cargo run -- test
```

## 🧪 Testing
The project includes unit and integration tests for theme logic and D-Bus interaction.
```bash
cargo test
```

## 📄 License
This project is part of the `rde` ecosystem. Check individual files or the root repository for licensing information.
