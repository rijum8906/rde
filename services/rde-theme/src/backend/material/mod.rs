//! # Material 3 Backend
//!
//! Provides pure Material Design 3 color palette computation and seed extraction.

pub mod scheme;

pub use scheme::{
    FALLBACK_SEED_COLOR, MATERIAL_ALGORITHM_VERSION, SEED_EXTRACTOR_VERSION, compute_color_roles,
    extract_seed_from_wallpaper,
};
