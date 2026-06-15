use std::sync::Mutex;

use alsa::{
    Mixer,
    mixer::{Selem, SelemChannelId, SelemId},
};
use zbus::{
    fdo::{Error, Result},
    interface,
    object_server::SignalEmitter,
};

// contains all the method and properties that will be in the actual dbus servcice
pub trait VolumeService {
    /// This actually returns the volume percentage
    fn get_volume(&self) -> Result<u8>;
    fn set_volume(&self, volume_percentage: u8) -> Result<()>;
    fn increase_volume(&self, volume_percentage: u8) -> Result<()>;
    fn decrease_volume(&self, volume_percentage: u8) -> Result<()>;
}

// Implementation
pub struct VolumeController {
    mixer: Mutex<Mixer>, // keep the mixer alive
    selem_name: String,  // Store the control name to find it each time
    max_volume: u64,
    min_volume: u64,
    max_volume_percentage_limit: u8,
}

impl VolumeController {
    pub fn new() -> Result<Self> {
        let mixer = match Mixer::new("default", false) {
            Ok(v) => v,
            Err(e) => return Err(Error::Failed(e.to_string())),
        };

        let selem = match mixer.find_selem(&SelemId::new("Master", 0)) {
            Some(v) => v,
            None => {
                return Err(Error::Failed("No master control".to_string()));
            }
        };

        // Get volume range
        let (min, max) = selem.get_playback_volume_range();

        Ok(Self {
            mixer: Mutex::new(mixer),
            selem_name: "Master".to_string(),
            min_volume: min as u64,
            max_volume: max as u64,
            max_volume_percentage_limit: 100,
        })
    }

    fn with_selem<F, T>(&self, f: F) -> Result<T>
    where
        F: FnOnce(&Selem) -> Result<T>,
    {
        let mixer = self.mixer.lock().unwrap();
        let selem_id = SelemId::new(&self.selem_name, 0);

        match mixer.find_selem(&selem_id) {
            Some(selem) => f(&selem),
            None => Err(Error::Failed("Master control not found".to_string())),
        }
    }
}

// Hleper private methods to handle the actual logic
impl VolumeController {
    fn get_volume_percentage(&self) -> Result<u8> {
        self.with_selem(|selem| {
            let current = match selem.get_playback_volume(SelemChannelId::mono()) {
                Ok(v) => v,
                Err(e) => return Err(Error::Failed(e.to_string())),
            };
            let range = self.min_volume - self.max_volume;
            if range == 0 {
                return Ok(0);
            }

            Ok(((current - self.min_volume as i64) * 100 / range as i64) as u8)
        })
    }

    fn set_volume_percentage(&self, value: u8) -> Result<()> {
        self.with_selem(|selem| {
            let target = self.min_volume as i64
                + (value as i64 * (self.max_volume - self.min_volume) as i64 / 100);
            match selem.set_playback_volume_all(target) {
                Ok(_) => Ok(()),
                Err(e) => Err(Error::Failed(e.to_string())),
            }
        })
    }
}

#[interface(name = "org.rde.Volume")]
impl VolumeController {
    // properties

    #[zbus(property, name = "Volume")]
    fn get_volume(&self) -> Result<u8> {
        self.get_volume_percentage()
    }

    #[zbus(property, name = "Volume")]
    pub async fn set_volume(
        &self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        percentage_value: u8,
    ) -> Result<()> {
        if percentage_value > self.max_volume_percentage_limit {
            return Err(Error::InvalidArgs(
                "Volume percentage exceeds 100%".to_string(),
            ));
        }
        // NOTE: the percentage_value can't be less that 0 because of the type

        self.set_volume_percentage(percentage_value)?;
        Self::emit_volume_changed(&ctxt, percentage_value)
            .await
            .map_err(|e| Error::Failed(e.to_string()))?;
        Ok(())
    }

    #[zbus(property, name = "Volume")]
    pub async fn increase_volume(
        &self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        volume_percentage: u8,
    ) -> Result<()> {
        let current_volume_percentage = self.get_volume_percentage()?;
        let total_volume_percentage = current_volume_percentage.saturating_add(volume_percentage);

        if total_volume_percentage > self.max_volume_percentage_limit {
            return Err(Error::InvalidArgs(
                "Volume percentage exceeds 100%".to_string(),
            ));
        }

        self.set_volume_percentage(total_volume_percentage)?;
        Self::emit_volume_changed(&ctxt, volume_percentage)
            .await
            .map_err(|e| Error::Failed(e.to_string()))?;
        Ok(())
    }

    pub async fn decrease_volume(
        &self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        volume_percentage: u8,
    ) -> Result<()> {
        let current_volume_percentage = self.get_volume_percentage()?;
        let total_volume_percentage = current_volume_percentage.saturating_sub(volume_percentage);

        self.set_volume_percentage(total_volume_percentage)?;
        Self::emit_volume_changed(&ctxt, volume_percentage)
            .await
            .map_err(|e| Error::Failed(e.to_string()))?;
        Ok(())
    }

    // Signals
    #[zbus(signal, name = "VolumeChanged")]
    async fn emit_volume_changed(ctxt: &SignalEmitter<'_>, percent: u8) -> zbus::Result<()>;
}
