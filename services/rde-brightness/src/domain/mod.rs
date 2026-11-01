//! # Domain Layer
//!
//! Display detection and brightness actuation rules. This layer depends only on
//! the standard library, `thiserror`, and `tracing`, and never on D-Bus or an
//! async runtime.

pub mod brightness;
pub mod display;
pub mod error;

pub use brightness::BrightnessLevel;
pub use display::DisplayInfo;
pub use error::DomainError;
