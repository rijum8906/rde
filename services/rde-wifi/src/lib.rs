//! # RDE Wi-Fi Service (`rde-wifi`)
//!
//! `rde-wifi` is a decoupled microservice within the Riju Desktop Environment (RDE).
//! It provides high-level Wi-Fi network management capabilities by interfacing with
//! Linux's system NetworkManager D-Bus service (`org.freedesktop.NetworkManager`).
//!
//! ## Architecture Overview
//! - **`app`**: Lifecycle management, singleton initialization, logging, and application entry points.
//! - **`backend`**: Core domain engine managing Wi-Fi hardware state, scanning access points, and connection profiles.
//! - **`dbus`**: Public session D-Bus interface (`org.rde.wifi`) exposed to desktop components and shell widgets.
//! - **`domain`**: Domain models, security enums, access point representations, and event definitions.
//! - **`infra`**: Low-level system D-Bus proxy traits (`zbus`) and unit-test mocks (`mockall`).
//! - **`ipc`**: Inter-Process Communication handler connecting to `rde-daemon` supervisor via Unix sockets.

pub mod app;
pub mod backend;
pub mod dbus;
pub mod domain;
pub mod infra;
pub mod ipc;
