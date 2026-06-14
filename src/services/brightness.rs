pub struct BrightnessController {
    value: u16,
}

impl BrightnessController {
    pub fn value(&self) -> u16 {
        self.value
    }

    pub fn set_value(&mut self, value: u16) {
        self.value = value;
    }
}
