mod execute;

pub use execute::execute;

use clap::Subcommand;

#[derive(Debug, Clone, Subcommand)]
pub enum ThemeCommand {
    /// Apply a specific theme
    Apply {
        /// The name of the theme
        name: String,

        /// The variant (light or dark)
        #[arg(short, long, default_value = "dark")]
        variant: String,
    },
    /// List all available themes
    List,
}
