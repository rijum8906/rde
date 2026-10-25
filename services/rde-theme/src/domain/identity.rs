//! # Identity Types
//!
//! Validated newtypes for theme identifiers and variant identifiers.

use serde::{Deserialize, Serialize};
use std::{fmt, ops::Deref};
use thiserror::Error;
use zbus::zvariant::Type;

/// Validation errors for theme and variant identifiers.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum IdError {
    /// Identifier string is empty.
    #[error("identifier cannot be empty")]
    Empty,

    /// Identifier exceeds maximum length of 64 characters.
    #[error("identifier is too long (maximum 64 characters)")]
    TooLong,

    /// Identifier contains an invalid character.
    #[error("identifier contains invalid character '{0}'")]
    InvalidChar(char),

    /// Identifier begins with a hyphen.
    #[error("identifier cannot start with a hyphen")]
    LeadingHyphen,

    /// Identifier ends with a hyphen.
    #[error("identifier cannot end with a hyphen")]
    TrailingHyphen,

    /// Identifier contains consecutive hyphens.
    #[error("identifier cannot contain consecutive hyphens ('--')")]
    ConsecutiveHyphens,

    /// Identifier uses a reserved name.
    #[error("identifier is reserved and cannot be used for custom themes")]
    Reserved,
}

fn validate_id_grammar(s: &str) -> Result<(), IdError> {
    // Step 1: Reject empty identifiers.
    if s.is_empty() {
        return Err(IdError::Empty);
    }

    // Step 2: Enforce 64-character limit.
    if s.len() > 64 {
        return Err(IdError::TooLong);
    }

    // Step 3: Check first character: [a-z0-9], explicitly disallow leading hyphen.
    let first = s.chars().next().ok_or(IdError::Empty)?;
    if first == '-' {
        return Err(IdError::LeadingHyphen);
    }
    if !first.is_ascii_lowercase() && !first.is_ascii_digit() {
        return Err(IdError::InvalidChar(first));
    }

    // Step 4: Check trailing character: cannot be hyphen.
    let last = s.chars().next_back().ok_or(IdError::Empty)?;
    if last == '-' {
        return Err(IdError::TrailingHyphen);
    }

    // Step 5: Check all characters and consecutive hyphens.
    let mut prev_hyphen = false;
    for ch in s.chars() {
        // Reject path separators, tilde, and any non-allowed characters.
        if ch == '/' || ch == '\\' || ch == '.' || ch == '~' {
            return Err(IdError::InvalidChar(ch));
        }

        if ch == '-' {
            if prev_hyphen {
                return Err(IdError::ConsecutiveHyphens);
            }
            prev_hyphen = true;
        } else if ch.is_ascii_lowercase() || ch.is_ascii_digit() {
            prev_hyphen = false;
        } else {
            return Err(IdError::InvalidChar(ch));
        }
    }

    Ok(())
}

/// A validated theme identifier.
///
/// Grammar: `[a-z0-9][a-z0-9-]{0,63}`, no leading/trailing '-', no '--',
/// no path separators, no `..`, no `~`, non-empty.
///
/// The reserved identifier `"rde-dynamic"` is used for the built-in dynamic theme.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, Type)]
#[serde(try_from = "String", into = "String")]
pub struct ThemeId(String);

impl ThemeId {
    /// Reserved identifier for the built-in dynamic theme.
    pub const DYNAMIC: &'static str = "rde-dynamic";

    /// Creates a [`ThemeId`] for the built-in dynamic theme.
    #[must_use]
    pub fn builtin_dynamic() -> Self {
        Self(Self::DYNAMIC.to_string())
    }

    /// Returns `true` if this identifier is the built-in dynamic theme.
    #[must_use]
    pub fn is_builtin(&self) -> bool {
        self.0 == Self::DYNAMIC
    }

    /// Validates and constructs a new non-reserved [`ThemeId`].
    ///
    /// # Errors
    /// Returns [`IdError::Reserved`] if `s == "rde-dynamic"`, or an [`IdError`] variant
    /// if grammar validation fails.
    pub fn new(s: impl AsRef<str>) -> Result<Self, IdError> {
        let text = s.as_ref();
        validate_id_grammar(text)?;
        if text == Self::DYNAMIC {
            return Err(IdError::Reserved);
        }
        Ok(Self(text.to_string()))
    }

    /// Returns a string slice representing the identifier.
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Deref for ThemeId {
    type Target = str;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl AsRef<str> for ThemeId {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for ThemeId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl TryFrom<String> for ThemeId {
    type Error = IdError;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        if value == Self::DYNAMIC {
            Ok(Self(value))
        } else {
            Self::new(value)
        }
    }
}

impl From<ThemeId> for String {
    fn from(id: ThemeId) -> Self {
        id.0
    }
}

/// A validated variant identifier.
///
/// Follows the same grammar as [`ThemeId`].
/// Conventional values include `"light"`, `"dark"`, `"light-high-contrast"`, etc.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, Type)]
#[serde(try_from = "String", into = "String")]
pub struct VariantId(String);

impl VariantId {
    /// Conventional variant name for standard light mode.
    pub const LIGHT: &'static str = "light";
    /// Conventional variant name for standard dark mode.
    pub const DARK: &'static str = "dark";
    /// Conventional variant name for light medium contrast.
    pub const LIGHT_MEDIUM_CONTRAST: &'static str = "light-medium-contrast";
    /// Conventional variant name for light high contrast.
    pub const LIGHT_HIGH_CONTRAST: &'static str = "light-high-contrast";
    /// Conventional variant name for dark medium contrast.
    pub const DARK_MEDIUM_CONTRAST: &'static str = "dark-medium-contrast";
    /// Conventional variant name for dark high contrast.
    pub const DARK_HIGH_CONTRAST: &'static str = "dark-high-contrast";

    /// Validates and constructs a new [`VariantId`].
    ///
    /// # Errors
    /// Returns [`IdError`] if grammar validation fails.
    pub fn new(s: impl AsRef<str>) -> Result<Self, IdError> {
        let text = s.as_ref();
        validate_id_grammar(text)?;
        Ok(Self(text.to_string()))
    }

    /// Constructs a [`VariantId`] from a crate-internal literal without re-validating grammar.
    ///
    /// # Parameters
    /// - `id`: a literal defined inside this crate, such as [`VariantId::LIGHT`]
    ///
    /// # Crate Use
    /// Reserved for identifiers the crate itself defines (the built-in dynamic
    /// variants), where the grammar is guaranteed by the constant itself.
    #[must_use]
    pub(crate) fn from_trusted_literal(id: &'static str) -> Self {
        Self(id.to_string())
    }

    /// Returns a string slice representing the variant identifier.
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Deref for VariantId {
    type Target = str;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl AsRef<str> for VariantId {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for VariantId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl TryFrom<String> for VariantId {
    type Error = IdError;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        Self::new(value)
    }
}

impl From<VariantId> for String {
    fn from(id: VariantId) -> Self {
        id.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_theme_ids() {
        assert!(ThemeId::new("nord").is_ok());
        assert!(ThemeId::new("catppuccin-latte").is_ok());
        assert!(ThemeId::new("theme1").is_ok());
        assert!(ThemeId::new("a-1-b").is_ok());
    }

    #[test]
    fn test_theme_id_empty() {
        assert_eq!(ThemeId::new(""), Err(IdError::Empty));
    }

    #[test]
    fn test_theme_id_too_long() {
        let long_str = "a".repeat(65);
        assert_eq!(ThemeId::new(long_str), Err(IdError::TooLong));
        let max_str = "a".repeat(64);
        assert!(ThemeId::new(max_str).is_ok());
    }

    #[test]
    fn test_theme_id_invalid_char() {
        assert_eq!(ThemeId::new("Nord"), Err(IdError::InvalidChar('N')));
        assert_eq!(ThemeId::new("nord_dark"), Err(IdError::InvalidChar('_')));
        assert_eq!(ThemeId::new("theme/sub"), Err(IdError::InvalidChar('/')));
        assert_eq!(ThemeId::new("theme\\sub"), Err(IdError::InvalidChar('\\')));
        assert_eq!(ThemeId::new(".."), Err(IdError::InvalidChar('.')));
        assert_eq!(ThemeId::new("~theme"), Err(IdError::InvalidChar('~')));
    }

    #[test]
    fn test_theme_id_leading_trailing_hyphens() {
        assert_eq!(ThemeId::new("-nord"), Err(IdError::LeadingHyphen));
        assert_eq!(ThemeId::new("nord-"), Err(IdError::TrailingHyphen));
    }

    #[test]
    fn test_theme_id_consecutive_hyphens() {
        assert_eq!(ThemeId::new("nord--dark"), Err(IdError::ConsecutiveHyphens));
    }

    #[test]
    fn test_theme_id_reserved() {
        assert_eq!(ThemeId::new(ThemeId::DYNAMIC), Err(IdError::Reserved));
        let builtin = ThemeId::builtin_dynamic();
        assert!(builtin.is_builtin());
        assert_eq!(builtin.as_str(), ThemeId::DYNAMIC);
    }

    #[test]
    fn test_variant_id_validation() {
        assert!(VariantId::new("light").is_ok());
        assert!(VariantId::new("dark").is_ok());
        assert!(VariantId::new("light-high-contrast").is_ok());
        assert_eq!(VariantId::new(""), Err(IdError::Empty));
        assert_eq!(VariantId::new("-dark"), Err(IdError::LeadingHyphen));
        assert_eq!(VariantId::new("dark-"), Err(IdError::TrailingHyphen));
        assert_eq!(
            VariantId::new("dark--contrast"),
            Err(IdError::ConsecutiveHyphens)
        );
        assert_eq!(VariantId::new("Dark"), Err(IdError::InvalidChar('D')));
    }

    #[test]
    fn test_serde_roundtrip() {
        let id = ThemeId::new("catppuccin").unwrap();
        let json = serde_json::to_string(&id).unwrap();
        assert_eq!(json, "\"catppuccin\"");
        let deserialized: ThemeId = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized, id);

        // Reserved id deserializes successfully (for builtin)
        let builtin_json = format!("\"{}\"", ThemeId::DYNAMIC);
        let builtin: ThemeId = serde_json::from_str(&builtin_json).unwrap();
        assert!(builtin.is_builtin());

        // Invalid id fails deserialization
        assert!(serde_json::from_str::<ThemeId>("\"catppuccin--mocha\"").is_err());
    }
}
