//! # Infrastructure Layer
//!
//! Adapters that expose the application service to the outside world: the
//! `org.rde.Brightness` D-Bus object and the `rde-daemon` supervision socket.

pub mod dbus;
pub mod ipc;
