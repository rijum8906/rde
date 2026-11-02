//! # D-Bus Presentation Module (`rde-volume`)
//!
//! Publishes the `org.rde.Volume` object on the session bus, mapping property
//! reads and writes onto the shared volume backend.

pub mod iface;
