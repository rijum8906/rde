use alsa::{Mixer, PollDescriptors, mixer::{SelemChannelId, SelemId}};
use rde_core::errors::{RdeError, RdeResult};

/// Volume badkend constains all the methods needed to change and manaege the volume
pub struct VolumeBackend {
    mixer: Mixer,
    selem_id: SelemId,
}

impl VolumeBackend {
    pub fn new() -> RdeResult<Self> {
        // open the default mixer
        let mixer = Mixer::new("default", false)
            .map_err(|e| RdeError::ConfigNotFound(format!("Failed to open mixer: {}", e)))?;

        // Find the Master control
        let selem_id = SelemId::new("Master", 0);

        // Verify the control exists
        if mixer.find_selem(&selem_id).is_none() {
            return Err(RdeError::ConfigNotFound(
                "No Master control found".to_string(),
            ));
        }

        Ok(Self { mixer, selem_id })
    }

    /// Get current volume (0-100)
    pub fn get_volume(&self) -> RdeResult<u8> {
        // Get the current volume
        let vol = self
            .mixer
            .get().map_err(|e| RdeError::ConfigNotFound(e.to_string()))?.get(SelemChannelId::FrontLeft);

        self.selem_id.try_intoH

        // Get min and max range
        let (min, max) = self
            .mixer
            .selem_get_playback_volume_range(&self.selem_id)
            .map_err(|e| format!("Failed to get volume range: {}", e))?;

        // Convert to percentage (0-100)
        let percentage = ((vol - min) * 100 / (max - min)) as u8;
        Ok(percentage)
    }
}
