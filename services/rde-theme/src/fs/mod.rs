//! # Filesystem Primitives
//!
//! Filesystem primitives for atomic updates and path verification.

pub mod atomic;
pub mod ensure;

pub use atomic::write_atomic;
pub use ensure::{EnsureError, ensure_dir, ensure_file};
