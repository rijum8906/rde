//! # Material 3 Color Scheme
//!
//! Provides pure Material Design 3 color palette computation from seed colors.

pub mod scheme;

pub use scheme::{FALLBACK_SEED_COLOR, MATERIAL_ALGORITHM_VERSION, compute_color_roles};
