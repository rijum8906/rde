use std::{
    fs,
    path::Path,
    sync::{Arc, Mutex},
};

use rde_brightness::brightness::{Brightness, BrightnessController, Executor};
use rde_brightness::constants::{BRIGHTNESS_FILE, MAX_BRIGHTNESS_FILE};
use tempfile::TempDir;
use zbus::fdo::Result;

/// A mock executor that records the last value sent to the "system"
struct MockExecutor {
    last_value: Arc<Mutex<Option<u16>>>,
}

impl MockExecutor {
    fn new() -> Self {
        Self {
            last_value: Arc::new(Mutex::new(None)),
        }
    }

    fn get_last_value(&self) -> Option<u16> {
        *self.last_value.lock().unwrap()
    }
}

impl Executor for MockExecutor {
    fn execute(&self, _path: &Path, value: u16) -> Result<()> {
        let mut last = self.last_value.lock().unwrap();
        *last = Some(value);
        Ok(())
    }
}

/// Helper to create a test environment
struct TestEnv {
    _tmp: TempDir,
    controller: BrightnessController,
    executor: Arc<MockExecutor>,
}

impl TestEnv {
    fn new(device_name: &str, current: u16, max: u16) -> Self {
        let tmp = TempDir::new().expect("Failed to create temp dir");
        let device_dir = tmp.path().join(device_name);
        fs::create_dir_all(&device_dir).expect("Failed to create device dir");

        fs::write(device_dir.join(BRIGHTNESS_FILE), current.to_string())
            .expect("Failed to write brightness");
        fs::write(device_dir.join(MAX_BRIGHTNESS_FILE), max.to_string())
            .expect("Failed to write max brightness");

        let executor = Arc::new(MockExecutor::new());
        let controller = BrightnessController::with_executor(
            tmp.path().to_str().unwrap(),
            executor.clone() as Arc<dyn Executor>,
        )
        .expect("Failed to create controller");

        Self {
            _tmp: tmp,
            controller,
            executor,
        }
    }
}

#[test]
fn test_initial_values() -> Result<()> {
    let env = TestEnv::new("backlight", 50, 100);

    assert_eq!(env.controller.get_max_brightness()?, 100);
    assert_eq!(env.controller.get_brightness()?, 50);
    assert_eq!(env.controller.get_brightness_percentage()?, 50);

    Ok(())
}

#[test]
fn test_set_brightness() -> Result<()> {
    let env = TestEnv::new("backlight", 50, 100);

    env.controller.set_brightness(75)?;
    assert_eq!(env.executor.get_last_value(), Some(75));

    Ok(())
}

#[test]
fn test_set_brightness_out_of_range() {
    let env = TestEnv::new("backlight", 50, 100);

    let result = env.controller.set_brightness(150);
    assert!(result.is_err());
}

#[test]
fn test_set_brightness_percentage() -> Result<()> {
    let env = TestEnv::new("backlight", 50, 200);

    // 25% of 200 is 50
    env.controller.set_brightness_percentage(25)?;
    assert_eq!(env.executor.get_last_value(), Some(50));

    Ok(())
}

#[test]
fn test_increase_brightness() -> Result<()> {
    let env = TestEnv::new("backlight", 50, 100);

    Brightness::increase_brightness(&env.controller, 10)?;
    assert_eq!(env.executor.get_last_value(), Some(60));

    // Test saturation
    Brightness::increase_brightness(&env.controller, 100)?;
    assert_eq!(env.executor.get_last_value(), Some(100));

    Ok(())
}

#[test]
fn test_decrease_brightness() -> Result<()> {
    let env = TestEnv::new("backlight", 50, 100);

    Brightness::decrease_brightness(&env.controller, 10)?;
    assert_eq!(env.executor.get_last_value(), Some(40));

    // Test saturation
    Brightness::decrease_brightness(&env.controller, 100)?;
    assert_eq!(env.executor.get_last_value(), Some(0));

    Ok(())
}

#[test]
fn test_increase_brightness_percentage() -> Result<()> {
    let env = TestEnv::new("backlight", 50, 100);

    Brightness::increase_brightness_percentage(&env.controller, 10)?;
    assert_eq!(env.executor.get_last_value(), Some(60));

    // Test saturation
    Brightness::increase_brightness_percentage(&env.controller, 100)?;
    assert_eq!(env.executor.get_last_value(), Some(100));

    Ok(())
}

#[test]
fn test_decrease_brightness_percentage() -> Result<()> {
    let env = TestEnv::new("backlight", 50, 100);

    Brightness::decrease_brightness_percentage(&env.controller, 10)?;
    assert_eq!(env.executor.get_last_value(), Some(40));

    // Test saturation
    Brightness::decrease_brightness_percentage(&env.controller, 100)?;
    assert_eq!(env.executor.get_last_value(), Some(0));

    Ok(())
}

#[test]
fn test_rounding_in_percentages() -> Result<()> {
    let env = TestEnv::new("backlight", 33, 100);

    // 33/100 = 33%
    assert_eq!(env.controller.get_brightness_percentage()?, 33);

    let env2 = TestEnv::new("backlight", 66, 200);
    // 66/200 = 33%
    assert_eq!(env2.controller.get_brightness_percentage()?, 33);

    // Set 33% of 200 = 66
    env2.controller.set_brightness_percentage(33)?;
    assert_eq!(env2.executor.get_last_value(), Some(66));

    Ok(())
}
