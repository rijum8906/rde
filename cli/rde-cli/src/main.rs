use clap::Parser;
use rdectl::command::{Command, theme};

#[derive(Parser, Debug)]
#[command(name = "rdectl")]
#[command(version = "0.0.1")]
#[command(about = "RDE controller command line interface")]
struct Cli {
    /// The command to execute
    #[command(subcommand)]
    command: Command,

    /// Number of times to execute the command
    #[arg(short, long, default_value_t = 1)]
    count: u8,
}

fn main() -> Result<(), std::io::Error> {
    let cli = Cli::parse();

    // Execute the command `cli.count` times
    for _ in 0..cli.count {
        match &cli.command {
            Command::Theme { command } => theme::execute(command)?,
        }
    }

    Ok(())
}
