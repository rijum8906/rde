//! # D-Bus Interface
//!
//! Serves `org.rde.Brightness` at `/org/rde/Brightness`, translating D-Bus
//! calls into [`BrightnessCommand`]s for the application service.
//!
//! Privileged sysfs writes never happen on the bus connection: the service
//! falls back to `pkexec`, which authorises `rde-brightness-helper` through the
//! `org.rde.brightness.set` polkit action shipped in `assets/polkit/`.

use std::sync::Arc;

use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info};
use zbus::object_server::SignalEmitter;

use crate::{
    DBUS_OBJECT_PATH, DBUS_SERVICE_NAME, SERVICE_VERSION,
    application::{ApplicationError, BrightnessCommand, BrightnessService},
};

/// D-Bus object implementing `org.rde.Brightness`.
#[derive(Debug)]
pub struct BrightnessInterface {
    /// Application service every property and method is routed through.
    service: Arc<BrightnessService>,
}

impl BrightnessInterface {
    /// Wraps the application service in the D-Bus interface.
    pub fn new(service: Arc<BrightnessService>) -> Self {
        Self { service }
    }

    /// Applies a command off the async executor and returns the new percentage.
    async fn apply(&self, command: BrightnessCommand) -> zbus::fdo::Result<u32> {
        // Step 1: Domain actuation is blocking, so keep it off the bus thread.
        let service = Arc::clone(&self.service);
        tokio::task::spawn_blocking(move || service.execute(command))
            .await
            .map_err(|error| {
                zbus::fdo::Error::Failed(format!("brightness worker failed: {error}"))
            })?
            .map_err(fdo_failure)?;

        // Step 2: Report the percentage the service recorded.
        Ok(u32::from(self.service.snapshot().percent))
    }
}

/// Publishes the interface and serves it until `shutdown` is cancelled.
///
/// # Errors
/// Returns an error when the session bus is unavailable, the well-known name
/// cannot be claimed, or the object cannot be registered.
pub async fn serve(
    service: Arc<BrightnessService>,
    shutdown: CancellationToken,
) -> Result<(), ApplicationError> {
    // Step 1: Claim `org.rde.Brightness` and export the object in one build.
    let connection = zbus::connection::Builder::session()
        .name(DBUS_SERVICE_NAME)
        .serve_at(DBUS_OBJECT_PATH, BrightnessInterface::new(service))
        .build()
        .await?;

    debug!(
        service = DBUS_SERVICE_NAME,
        path = DBUS_OBJECT_PATH,
        pid = std::process::id(),
        "D-Bus interface registered"
    );

    // Step 2: Keep the connection alive until shutdown is requested.
    shutdown.cancelled().await;
    info!("D-Bus interface released");
    drop(connection);

    Ok(())
}

/// Converts an application failure into a D-Bus error.
fn fdo_failure(error: ApplicationError) -> zbus::fdo::Error {
    error!(%error, "Brightness command failed");
    zbus::fdo::Error::Failed(format!("{error:#}"))
}

#[zbus::interface(name = "org.rde.Brightness")]
impl BrightnessInterface {
    /// Service version string.
    #[zbus(property(emits_changed_signal = "false"))]
    pub fn version(&self) -> String {
        SERVICE_VERSION.to_string()
    }

    /// Current raw brightness value on the target display's scale.
    #[zbus(property(emits_changed_signal = "false"))]
    pub fn brightness(&self) -> u32 {
        self.service.snapshot().raw
    }

    /// Sets the raw brightness value of the active display.
    ///
    /// # Errors
    /// Returns a D-Bus failure when the write is rejected.
    #[zbus(property)]
    pub async fn set_brightness(
        &self,
        brightness: u32,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Convert the raw value into the percentage the domain expects.
        let snapshot = self.service.snapshot();
        let percent = if snapshot.max == 0 {
            0
        } else {
            (u64::from(brightness.min(snapshot.max)) * 100 / u64::from(snapshot.max)) as u8
        };

        // Step 2: Apply it and notify listeners.
        let applied = self
            .apply(BrightnessCommand::Set {
                output: snapshot.display.unwrap_or_default(),
                percent,
            })
            .await?;

        Self::brightness_changed(&emitter, applied)
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))
    }

    /// Current brightness as a percentage (0-100).
    #[zbus(property(emits_changed_signal = "false"))]
    pub fn brightness_percentage(&self) -> u32 {
        u32::from(self.service.snapshot().percent)
    }

    /// Sets the brightness percentage of the active display.
    ///
    /// # Errors
    /// Returns a D-Bus failure for percentages above 100 or a rejected write.
    #[zbus(property)]
    pub async fn set_brightness_percentage(
        &self,
        percent: u32,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Percentages travel as u32 on the wire but are u8 in the domain.
        let percent = u8::try_from(percent).map_err(|_| {
            zbus::fdo::Error::InvalidArgs(format!("brightness percentage {percent} is invalid"))
        })?;

        // Step 2: Apply it against the active display and notify listeners.
        let applied = self
            .apply(BrightnessCommand::Set {
                output: self.service.snapshot().display.unwrap_or_default(),
                percent,
            })
            .await?;

        Self::brightness_changed(&emitter, applied)
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))
    }

    /// Maximum brightness value of the target display's scale.
    #[zbus(property(emits_changed_signal = "false"))]
    pub fn max_brightness(&self) -> u32 {
        self.service.snapshot().max
    }

    /// Increases the active display brightness by `step` percentage points.
    ///
    /// # Returns
    /// The new brightness percentage, clamped to 100.
    #[zbus(name = "IncreaseBrightness")]
    pub async fn increase_brightness(
        &self,
        step: u32,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<u32> {
        // Step 1: Clamp the step to the percentage range before narrowing it.
        let step = step.min(100) as u8;
        let applied = self.apply(BrightnessCommand::Increase(step)).await?;

        // Step 2: Notify listeners of the resulting percentage.
        Self::brightness_changed(&emitter, applied)
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))?;

        Ok(applied)
    }

    /// Decreases the active display brightness by `step` percentage points.
    ///
    /// # Returns
    /// The new brightness percentage, saturated at 0.
    #[zbus(name = "DecreaseBrightness")]
    pub async fn decrease_brightness(
        &self,
        step: u32,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<u32> {
        // Step 1: Clamp the step to the percentage range before narrowing it.
        let step = step.min(100) as u8;
        let applied = self.apply(BrightnessCommand::Decrease(step)).await?;

        // Step 2: Notify listeners of the resulting percentage.
        Self::brightness_changed(&emitter, applied)
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))?;

        Ok(applied)
    }

    /// Emitted after every successful brightness change.
    ///
    /// # Parameters
    /// - `percent`: new brightness percentage (0-100)
    #[zbus(signal, name = "BrightnessChanged")]
    pub async fn brightness_changed(
        signal_emitter: &SignalEmitter<'_>,
        percent: u32,
    ) -> zbus::Result<()>;
}
