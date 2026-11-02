//! # D-Bus Presentation Adapter (`org.rde.Theme`)
//!
//! Exposes the theme service over the session D-Bus bus at object path `/org/rde/Theme`.
//!
//! The interface uses strongly-typed D-Bus properties and structs. Consumers
//! (Quickshell, Flutter, GTK) should subscribe to standard `PropertiesChanged`
//! and the custom `ThemeChanged` signals.

use std::{collections::HashMap, sync::Arc};
use tracing::warn;
use zbus::{OwnedVariant, Variant, interface, object_server::SignalEmitter};

use crate::{
    domain::{
        ResolvedTheme, ThemeManifest,
        identity::ThemeId,
        manifest::{Appearance, ContrastLevel},
        settings::DynamicThemeUpdate,
    },
    service::ThemeService,
    theme_store::ThemeError,
};

/// Object path for the public theme interface.
pub const THEME_OBJECT_PATH: &str = "/org/rde/Theme";

/// D-Bus interface name for `org.rde.Theme`.
pub const THEME_INTERFACE_NAME: &str = "org.rde.Theme";

/// Object path for the Freedesktop XDG Desktop Portal settings.
pub const PORTAL_OBJECT_PATH: &str = "/org/freedesktop/portal/desktop";

/// Interface name for the Freedesktop XDG Desktop Portal settings.
pub const PORTAL_INTERFACE_NAME: &str = "org.freedesktop.portal.Settings";

// =================================
// HELPERS
// =================================

/// Parses a string into an `Appearance`.
fn parse_appearance(s: &str) -> zbus::fdo::Result<Appearance> {
    match s.trim().to_lowercase().as_str() {
        "light" => Ok(Appearance::Light),
        "dark" => Ok(Appearance::Dark),
        other => Err(zbus::fdo::Error::InvalidArgs(format!(
            "invalid appearance '{other}' (expected 'light' or 'dark')"
        ))),
    }
}

/// Parses a string into a `ContrastLevel`.
fn parse_contrast(s: &str) -> zbus::fdo::Result<ContrastLevel> {
    match s.trim().to_lowercase().as_str() {
        "normal" => Ok(ContrastLevel::Normal),
        "medium" => Ok(ContrastLevel::Medium),
        "high" => Ok(ContrastLevel::High),
        other => Err(zbus::fdo::Error::InvalidArgs(format!(
            "invalid contrast '{other}' (expected 'normal', 'medium', or 'high')"
        ))),
    }
}

/// Helper to parse a ThemeId string safely.
fn parse_theme_id(id: &str) -> zbus::fdo::Result<ThemeId> {
    if id == ThemeId::DYNAMIC {
        Ok(ThemeId::builtin_dynamic())
    } else {
        ThemeId::new(id).map_err(|e| zbus::fdo::Error::InvalidArgs(e.to_string()))
    }
}

// =================================
// PUBLIC INTERFACE
// =================================

/// Public D-Bus interface adapter for `org.rde.Theme`.
pub struct ThemeInterface {
    service: Arc<ThemeService>,
}

impl ThemeInterface {
    /// Constructs a new [`ThemeInterface`] wrapping the application [`ThemeService`].
    #[must_use]
    pub fn new(service: Arc<ThemeService>) -> Self {
        Self { service }
    }

    /// Emits the portal `SettingChanged` signal for `org.freedesktop.appearance`.
    async fn emit_portal_color_scheme(emitter: &SignalEmitter<'_>, mode: Appearance) {
        let portal_emitter = match SignalEmitter::new(emitter.connection(), PORTAL_OBJECT_PATH) {
            Ok(emitter) => emitter,
            Err(err) => {
                warn!(error = %err, "Failed to create a portal SettingChanged emitter");
                return;
            }
        };

        let code: u32 = match mode {
            Appearance::Dark => 1,
            Appearance::Light => 2,
        };

        if let Err(err) = PortalSettingsInterface::setting_changed(
            &portal_emitter,
            "org.freedesktop.appearance",
            "color-scheme",
            Variant::U32(code),
        )
        .await
        {
            warn!(error = %err, "Failed to emit portal SettingChanged signal");
        }
    }
}

#[interface(name = "org.rde.Theme")]
impl ThemeInterface {
    // =================================
    // PROPERTIES
    // =================================

    /// Interface contract version.
    #[zbus(property)]
    pub fn version(&self) -> u32 {
        1
    }

    /// Identifier of the active theme (empty string if dynamic built-in).
    #[zbus(property)]
    pub async fn active_theme(&self) -> String {
        let state = self.service.current_state().await;
        state.active.map(|id| id.to_string()).unwrap_or_default()
    }

    /// Switches the active desktop theme.
    #[zbus(property)]
    pub async fn set_active_theme(
        &self,
        id: String,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        let theme_id = if id.trim().is_empty() {
            ThemeId::builtin_dynamic()
        } else {
            parse_theme_id(&id)?
        };

        self.service
            .set_active(theme_id)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // zbus automatically emits PropertiesChanged for ActiveTheme.
        // We manually emit the generation bump and the ThemeChanged struct.
        self.active_theme_changed(&emitter).await;

        Ok(())
    }

    /// Identifiers of all installed themes in the registry.
    #[zbus(property)]
    pub async fn available_themes(&self) -> Vec<String> {
        self.service
            .repository()
            .list()
            .await
            .unwrap_or_default()
            .into_iter()
            .map(|id| id.to_string())
            .collect()
    }

    /// Monotonically increasing generation number of the published theme.
    #[zbus(property)]
    pub async fn generation(&self) -> u32 {
        self.service.current_state().await.generation
    }

    /// Current appearance mode (`"light"` or `"dark"`).
    #[zbus(property)]
    pub async fn appearance(&self) -> String {
        match self.service.theme_mode().await {
            Appearance::Light => "light".to_string(),
            Appearance::Dark => "dark".to_string(),
        }
    }

    /// Sets the appearance mode.
    #[zbus(property)]
    pub async fn set_appearance(
        &self,
        mode: String,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        let target = parse_appearance(&mode)?;

        self.service
            .set_mode(target)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // zbus automatically emits PropertiesChanged for Appearance.
        // We manually emit the generation bump and the portal signal.
        self.generation_changed(&emitter).await;
        Self::emit_portal_color_scheme(&emitter, target).await;

        Ok(())
    }

    // =================================
    // METHODS
    // =================================

    /// Returns the currently active [`ResolvedTheme`].
    pub async fn get_resolved_theme(&self) -> zbus::fdo::Result<(ResolvedTheme,)> {
        let state = self.service.current_state().await;
        Ok((state.resolved,))
    }

    /// Returns the author [`ThemeManifest`] for the requested theme ID.
    pub async fn get_theme_manifest(&self, id: &str) -> zbus::fdo::Result<(ThemeManifest,)> {
        let theme_id = parse_theme_id(id)?;
        let manifest = self
            .service
            .repository()
            .manifest(&theme_id)
            .await
            .map_err(|e| {
                zbus::fdo::Error::Failed(format!("failed to load manifest for '{id}': {e}"))
            })?;
        Ok((manifest,))
    }

    /// Returns the list of installed theme IDs.
    pub async fn list_themes(&self) -> zbus::fdo::Result<Vec<ThemeId>> {
        self.service
            .repository()
            .list()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(format!("failed to list themes: {e}")))
    }

    /// Updates the seed colors of the built-in dynamic theme (`rde-dynamic`).
    pub async fn update_dynamic_theme(
        &self,
        primary: &str,
        secondary: &str,
        tertiary: &str,
        error: &str,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        let primary = primary.trim();
        if primary.is_empty() {
            return Err(zbus::fdo::Error::InvalidArgs(
                "a primary seed color is required".to_string(),
            ));
        }

        let seed_arg = |value: &str| Some(value.trim().to_string()).filter(|v| !v.is_empty());
        let update = DynamicThemeUpdate {
            primary: Some(primary.to_string()),
            secondary: seed_arg(secondary),
            tertiary: seed_arg(tertiary),
            error: seed_arg(error),
        };

        self.service
            .update_dynamic_theme(update)
            .await
            .map_err(|err| match err {
                ThemeError::Settings(_) => zbus::fdo::Error::InvalidArgs(err.to_string()),
                other => zbus::fdo::Error::Failed(other.to_string()),
            })?;

        // Manually emit generation bump since the Method changes it.
        self.generation_changed(&emitter).await;

        Ok(())
    }

    /// Forces a reload of the active theme manifest and variant files.
    pub async fn reload(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        self.service
            .reload()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Emit updated properties
        self.active_theme_changed(&emitter).await;
        self.generation_changed(&emitter).await;
        self.available_themes_changed(&emitter).await;

        // Emit custom reload signal
        if let Err(err) = Self::reloaded(&emitter).await {
            warn!(error = %err, "Failed to emit Reloaded signal");
        }

        Ok(())
    }

    /// Computes and returns a preview [`ResolvedTheme`] without committing.
    pub async fn preview(
        &self,
        id: &str,
        mode: &str,
        contrast: &str,
    ) -> zbus::fdo::Result<(ResolvedTheme,)> {
        let theme_id = parse_theme_id(id)?;
        let mode_val = parse_appearance(mode)?;
        let contrast_val = parse_contrast(contrast)?;

        let resolved = self
            .service
            .preview(&theme_id, mode_val, contrast_val)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(format!("failed to preview theme: {e}")))?;

        Ok((resolved,))
    }

    // =================================
    // SIGNALS
    // =================================

    /// Emitted whenever a reload operation completes.
    #[zbus(signal)]
    pub async fn reloaded(signal_ctxt: &SignalEmitter<'_>) -> zbus::Result<()>;
}

// =================================
// PORTAL INTERFACE
// =================================

/// Freedesktop XDG Desktop Portal `org.freedesktop.portal.Settings` interface adapter.
pub struct PortalSettingsInterface {
    service: Arc<ThemeService>,
}

impl PortalSettingsInterface {
    #[must_use]
    pub fn new(service: Arc<ThemeService>) -> Self {
        Self { service }
    }
}

#[interface(name = "org.freedesktop.portal.Settings")]
impl PortalSettingsInterface {
    /// Returns the active color-scheme setting (1 = Dark, 2 = Light).
    pub async fn read(&self, namespace: &str, key: &str) -> zbus::fdo::Result<OwnedVariant> {
        if namespace == "org.freedesktop.appearance" && key == "color-scheme" {
            let state = self.service.current_state().await;
            let code: u32 = match state.mode {
                Appearance::Dark => 1,
                Appearance::Light => 2,
            };
            Ok(OwnedVariant::from(code))
        } else {
            Err(zbus::fdo::Error::Failed("Key not found".into()))
        }
    }

    /// Reads all keys for requested namespaces.
    pub async fn read_all(
        &self,
        namespaces: Vec<String>,
    ) -> zbus::fdo::Result<HashMap<String, HashMap<String, OwnedVariant>>> {
        let mut result = HashMap::new();
        if namespaces.contains(&"org.freedesktop.appearance".to_string()) || namespaces.is_empty() {
            let state = self.service.current_state().await;
            let code: u32 = match state.mode {
                Appearance::Dark => 1,
                Appearance::Light => 2,
            };
            let mut appearance_map = HashMap::new();
            appearance_map.insert("color-scheme".to_string(), OwnedVariant::from(code));
            result.insert("org.freedesktop.appearance".to_string(), appearance_map);
        }
        Ok(result)
    }

    /// Emitted when a portal setting changes.
    #[zbus(signal)]
    pub async fn setting_changed(
        signal_ctxt: &SignalEmitter<'_>,
        namespace: &str,
        key: &str,
        value: Variant<'_>,
    ) -> zbus::Result<()>;
}

// =================================
// TESTS
// =================================

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        adapter::AdapterRegistry, service::ThemeService, theme_store::DiskThemeRepository,
    };
    use zbus::object_server::Interface;

    async fn temp_service(root: &std::path::Path) -> Arc<ThemeService> {
        let repo = Arc::new(DiskThemeRepository::new(
            root.join("themes"),
            root.join("config"),
            root.join("cache"),
        ));

        Arc::new(
            ThemeService::startup(
                repo,
                AdapterRegistry::default(),
                root.join("cache").join("current.json"),
                root.join("config").join("settings.toml"),
                root.join("themes"),
            )
            .await
            .expect("theme service must start"),
        )
    }

    #[tokio::test]
    async fn exposes_dynamic_theme_contract_in_introspection() {
        let temp = tempfile::tempdir().unwrap();
        let iface = ThemeInterface::new(temp_service(temp.path()).await);

        let mut xml = String::new();
        iface.introspect_to_writer(&mut xml, 0);

        // Methods
        for method in [
            "GetResolvedTheme",
            "GetThemeManifest",
            "ListThemes",
            "UpdateDynamicTheme",
            "Reload",
            "Preview",
        ] {
            assert!(xml.contains(method), "missing {method}: {xml}");
        }

        // Properties
        for name in ["ActiveTheme", "AvailableThemes", "Generation", "Appearance"] {
            assert!(xml.contains(name), "missing {name}: {xml}");
        }

        // Ensure mutation methods replaced by read-write properties are gone.
        for removed in ["SetMode", "SetActiveTheme"] {
            assert!(!xml.contains(removed), "{removed} should be removed: {xml}");
        }

        // Signals
        assert!(xml.contains("Reloaded"), "missing Reloaded signal: {xml}");
    }

    #[test]
    fn payload_signatures_match_the_settings_client_contract() {
        use zbus::zvariant::Type;

        let colors = format!("({})", "s".repeat(34));
        assert_eq!(
            ResolvedTheme::SIGNATURE.to_string(),
            format!("(ussu{colors}(ss)(ddddd)(uuuss))"),
        );
        assert_eq!(
            ThemeManifest::SIGNATURE.to_string(),
            "(ussssssa{s(uusss)}s)",
        );
    }
}
