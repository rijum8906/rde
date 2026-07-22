//! # Inter-Process Communication (IPC) Module
//!
//! Handles Unix domain socket communication between `rde-wifi` service and `rde-daemon` supervisor.
//! Provides health check responses, status updates, registration handshakes, and graceful shutdowns.

pub mod daemon_request;
pub mod daemon_response;
pub mod handler;
