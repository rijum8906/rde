mod execute;

#[derive(Debug, Clone, clap::Subcommand)]
pub enum ThemeCommand {
    Set { theme: String, mode: ThemeMode },
}

#[derive(Debug, Clone, clap::ValueEnum)]
pub enum ThemeMode {
    Light,
    Dark,
}

impl AsRef<std::ffi::OsStr> for ThemeMode {
    fn as_ref(&self) -> &std::ffi::OsStr {
        match self {
            ThemeMode::Light => std::ffi::OsStr::new("light"),
            ThemeMode::Dark => std::ffi::OsStr::new("dark"),
        }
    }
}
