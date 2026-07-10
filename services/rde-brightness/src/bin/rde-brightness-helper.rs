fn main() {
    // Get all the arguments passed to the helper
    let args: Vec<String> = std::env::args().collect();

    // The first argument is the path of the brightness file
    let brightness_path = &args[1];

    // The second one is the brightness value to write
    let brightness = &args[2];

    // write the file
    if let Err(e) = std::fs::write(brightness_path, brightness) {
        eprintln!("Failed to write brightness: {}", e);
    }
}
