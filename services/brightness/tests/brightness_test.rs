#[cfg(test)]
mod tests {
    use std::{fs, panic, path::PathBuf};

    use rde_brightness::{
        brightness::BrightnessController,
        constants::{BACKLIGHT_SYSFS_PATH, BRIGHTNESS_FILE, MAX_BRIGHTNESS_FILE},
    };

    #[test]
    fn test_new_controller() {
        let _ = match BrightnessController::new(BACKLIGHT_SYSFS_PATH) {
            Ok(c) => c,
            Err(e) => {
                panic!("Failed to create controller: {}", e);
            }
        };
    }

    #[test]
    fn test_controller_get_methods() {
        let controller = match BrightnessController::new(BACKLIGHT_SYSFS_PATH) {
            Ok(c) => c,
            Err(e) => {
                panic!("Failed to create controller: {}", e);
            }
        };

        // get brightness
        let brightness = controller.get_brightness().unwrap();
        assert!(brightness > 0);

        // get max brightness
        let max_brightness = controller.get_max_brightness().unwrap();
        assert!(max_brightness > 0);

        // current brightness should be less than max
        assert!(brightness < max_brightness);
    }

    #[test]
    fn tesst_controller_set_methods() {
        // Create a tmp file for this test
        let test_backlight_path = "/tmp/test_backlight/";

        let brightness_path = PathBuf::from(test_backlight_path)
            .join("test")
            .join(BRIGHTNESS_FILE);
        let brightness_file_content = "50";

        let max_brightness_path = PathBuf::from(test_backlight_path)
            .join("test")
            .join(MAX_BRIGHTNESS_FILE);
        let max_brightness_file_content = "100";

        fs::create_dir_all(test_backlight_path.to_string() + "test").unwrap();
        fs::write(brightness_path, brightness_file_content.as_bytes()).unwrap();
        fs::write(max_brightness_path, max_brightness_file_content.as_bytes()).unwrap();

        let controller = match BrightnessController::new(test_backlight_path) {
            Ok(c) => c,
            Err(e) => {
                panic!("Failed to create controller: {}", e);
            }
        };

        let max_brightness = controller.get_max_brightness().unwrap();

        // set brightness
        controller.set_brightness(max_brightness / 2 + 7).unwrap();
        let brightness = controller.get_brightness().unwrap();
        assert!(brightness == max_brightness / 2 + 7);
    }
}
