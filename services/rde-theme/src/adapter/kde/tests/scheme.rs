//! # Plasma Color Scheme Tests
//!
//! Pins the identity keys `plasma-apply-colorscheme` and Plasma's settings UI
//! read from the standalone `.colors` document.

use super::{KDE_COLOR_SCHEM_NAME, roles};
use crate::adapter::kde::render_color_scheme;

#[test]
fn color_scheme_carries_its_identity() {
    let content = render_color_scheme(&roles(), KDE_COLOR_SCHEM_NAME);

    assert!(content.contains("Name=RdeM3"), "{content}");
    assert!(content.contains("ColorScheme=RdeM3"), "{content}");
    assert!(content.contains("[Colors:Selection]"), "{content}");
}
