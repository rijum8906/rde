//! # Color Encoding Helpers
//!
//! Parses and formats the hexadecimal colors stored in manifests and published
//! over D-Bus.

use rde_core::errors::{RdeError, RdeResult};

/// Opaque alpha channel mask applied to every parsed color.
const OPAQUE_ALPHA: u32 = 0xFF00_0000;

/// Parses a hexadecimal color into packed opaque ARGB.
///
/// # Parameters
/// - `value`: color in `#RGB`, `RGB`, `#RRGGBB`, or `RRGGBB` form
///
/// # Returns
/// Packed ARGB color with the alpha channel forced to `0xFF`.
///
/// # Errors
/// Returns [`RdeError::InvalidValue`] when the string is not a three or six
/// digit hexadecimal color.
///
/// # Example
/// ```
/// use rde_theme::domain::color::parse_hex_color;
///
/// assert_eq!(parse_hex_color("#6dd6da")?, 0xFF6D_D6DA);
/// assert_eq!(parse_hex_color("f0f")?, 0xFFFF_00FF);
/// # Ok::<(), rde_core::errors::RdeError>(())
/// ```
pub fn parse_hex_color(value: &str) -> RdeResult<u32> {
    let trimmed = value.trim();
    let raw = trimmed.strip_prefix('#').unwrap_or(trimmed);

    // Step 1: Expand the `#RGB` shorthand so both forms share one parse path.
    let expanded = match raw.len() {
        3 => raw
            .chars()
            .flat_map(|digit| [digit, digit])
            .collect::<String>(),
        6 => raw.to_string(),
        _ => {
            return Err(RdeError::InvalidValue(format!(
                "color '{value}' must be a #RGB or #RRGGBB hexadecimal value"
            )));
        }
    };

    // Step 2: Decode the six hexadecimal digits; non-hex input is rejected here.
    let rgb = u32::from_str_radix(&expanded, 16).map_err(|_| {
        RdeError::InvalidValue(format!(
            "color '{value}' contains non-hexadecimal characters"
        ))
    })?;

    // Step 3: Force the alpha channel opaque; theme colors are never translucent.
    Ok(OPAQUE_ALPHA | rgb)
}

/// Formats a packed color as uppercase `#RRGGBB`.
///
/// # Parameters
/// - `argb`: packed ARGB color; the alpha channel is ignored
///
/// # Returns
/// Canonical color string, for example `#6DD6DA`.
pub fn format_hex_color(argb: u32) -> String {
    format!(
        "#{:02X}{:02X}{:02X}",
        (argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF,
        argb & 0xFF
    )
}

/// Parses a color and formats it back in canonical `#RRGGBB` form.
///
/// # Errors
/// Returns [`RdeError::InvalidValue`] when the value is not a valid hex color,
/// using the same rules as [`parse_hex_color`].
pub fn normalize_hex_color(value: &str) -> RdeResult<String> {
    parse_hex_color(value).map(format_hex_color)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_long_and_short_forms() {
        assert_eq!(
            parse_hex_color("#6dd6da").expect("six digit color"),
            0xFF6D_D6DA
        );
        assert_eq!(
            parse_hex_color("6DD6DA").expect("six digit color without hash"),
            0xFF6D_D6DA
        );
        assert_eq!(parse_hex_color("#f0f").expect("short color"), 0xFFFF_00FF);
        assert_eq!(
            parse_hex_color("  #000000 ").expect("padded color"),
            0xFF00_0000
        );
    }

    #[test]
    fn rejects_invalid_colors() {
        for value in ["", "#", "#12", "#12345", "#gggggg", "not-a-color"] {
            assert!(
                parse_hex_color(value).is_err(),
                "'{value}' must be rejected as a source color"
            );
        }
    }

    #[test]
    fn normalizes_to_uppercase_hash_form() {
        assert_eq!(
            normalize_hex_color("6dd6da").expect("valid color"),
            "#6DD6DA"
        );
        assert_eq!(format_hex_color(0xFF00_00FF), "#0000FF");
    }
}
