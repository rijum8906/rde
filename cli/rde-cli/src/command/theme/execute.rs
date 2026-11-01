use std::{io::Error, process::Command};

use crate::command::daemon::ThemeCommand;

pub fn execute(theme_command: &ThemeCommand) -> Result<(), Error> {
    match theme_command {
        ThemeCommand::Set { theme, mode } => {
            let output = Command::new("busctl")
                .args("--user call org.rde.Theme /org/rde/Theme org.rde.Theme SetMode s".split(" "))
                .arg(mode)
                .output()?;
            if output.status.success() {
                let _stdout = String::from_utf8_lossy(&output.stdout);
                println!("success");
                Ok(())
            } else {
                Err(Error::other(String::from_utf8_lossy(&output.stderr)))
            }
        }
    }
}
