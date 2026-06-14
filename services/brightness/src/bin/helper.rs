use std::{fs, path::PathBuf};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let path: String = args[1].parse().unwrap();
    let value: u16 = args[2].parse().unwrap();

    // Direct write - runs as root, so no permission error
    let backlight_path = PathBuf::from(path);

    // This would fail if service tried it, but works here because root
    fs::write(backlight_path, value.to_string()).unwrap();
}
