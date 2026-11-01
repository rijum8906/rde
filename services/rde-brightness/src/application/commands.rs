//! # Brightness Commands
//!
//! Intent-level requests the application service understands, independent of
//! the D-Bus or supervisor transport that delivered them.

/// A brightness change requested by a client.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BrightnessCommand {
    /// Set a display to an absolute percentage.
    Set {
        /// Connector name, e.g. `DP-1`. An empty value targets the active display.
        output: String,
        /// Target percentage (0-100).
        percent: u8,
    },

    /// Raise the active display by a step in percentage points.
    Increase(u8),

    /// Lower the active display by a step in percentage points.
    Decrease(u8),
}

impl BrightnessCommand {
    /// Returns the absolute percentage a relative command should apply.
    ///
    /// # Parameters
    /// - `current`: current percentage of the target display (0-100)
    ///
    /// # Returns
    /// The clamped target percentage for [`BrightnessCommand::Increase`] and
    /// [`BrightnessCommand::Decrease`]. Returns `None` for
    /// [`BrightnessCommand::Set`], which already carries an absolute value.
    pub fn adjusted_percent(&self, current: u8) -> Option<u8> {
        match self {
            Self::Set { .. } => None,
            Self::Increase(step) => Some(current.saturating_add(*step).min(100)),
            Self::Decrease(step) => Some(current.saturating_sub(*step)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn increase_clamps_at_one_hundred() {
        assert_eq!(
            BrightnessCommand::Increase(20).adjusted_percent(60),
            Some(80)
        );
        assert_eq!(
            BrightnessCommand::Increase(20).adjusted_percent(90),
            Some(100)
        );
        assert_eq!(
            BrightnessCommand::Increase(255).adjusted_percent(90),
            Some(100)
        );
    }

    #[test]
    fn decrease_saturates_at_zero() {
        assert_eq!(
            BrightnessCommand::Decrease(20).adjusted_percent(60),
            Some(40)
        );
        assert_eq!(
            BrightnessCommand::Decrease(20).adjusted_percent(10),
            Some(0)
        );
        assert_eq!(
            BrightnessCommand::Decrease(255).adjusted_percent(10),
            Some(0)
        );
    }

    #[test]
    fn set_has_no_relative_target() {
        let command = BrightnessCommand::Set {
            output: "DP-1".to_string(),
            percent: 40,
        };

        assert_eq!(command.adjusted_percent(80), None);
    }
}
