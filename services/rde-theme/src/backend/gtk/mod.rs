//! # GTK Theme Backend
//!
//! Serves the active palette to GTK 3 and GTK 4 applications through a generated
//! CSS override.

pub mod css;

pub use css::render_css;
