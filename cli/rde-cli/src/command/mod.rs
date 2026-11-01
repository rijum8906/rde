use clap::Subcommand;

use crate::command::daemon::ThemeCommand;

mod daemon;
pub mod theme;

#[derive(Debug, Clone, Subcommand)]
pub enum Command {
    /// Manage the system theme
    Theme {
        #[command(subcommand)]
        command: ThemeCommand,
    },
}
