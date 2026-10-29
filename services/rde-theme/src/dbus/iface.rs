//! # D-Bus Presentation Adapter (`org.rde.Theme`)
//!
//! Exposes the theme service over the session D-Bus bus at object path `/org/rde/Theme`.
//!
//! All data return values are serialized as JSON strings to guarantee backwards
//! compatibility across toolkit consumers (C/GTK, Flutter, Qt, Shell scripts).

use std::{collections::HashMap, sync::Arc};
use zbus::{OwnedVariant, Variant, interface, object_server::SignalEmitter};

use crate::{
    domain::{
        ResolvedTheme, ThemeManifest,
        identity::ThemeId,
        manifest::{ContrastLevel, ThemeMode},
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

    /// Current appearance mode (`"light"` or `"dark"`).
    #[zbus(property)]
    pub async fn mode(&self) -> String {
        match self.service.theme_mode().await {
            ThemeMode::Light => "light".to_string(),
            ThemeMode::Dark => "dark".to_string(),
        }
    }

    /// Identifiers of all installed themes in the registry.
    #[zbus(property)]
    pub async fn available_themes(&self) -> Vec<String> {
        let repo = self.service.repository();
        repo.list()
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

    // =================================
    // METHODS
    // =================================

    /// Returns the currently active [`crate::domain::resolved::ResolvedTheme`].
    ///
    /// The payload is wrapped in a one-element tuple: zbus 5 flattens a bare
    /// struct return into separate out arguments, while consumers expect a
    /// single D-Bus struct value.
    pub async fn get_resolved_theme(&self) -> zbus::fdo::Result<(ResolvedTheme,)> {
        let state = self.service.current_state().await;
        Ok((state.resolved,))
    }

    /// Returns the author [`crate::domain::manifest::ThemeManifest`] for the requested theme ID.
    ///
    /// Like [`Self::get_resolved_theme`], the manifest is returned as a single
    /// D-Bus struct value through a one-element tuple.
    pub async fn get_theme_manifest(&self, id: &str) -> zbus::fdo::Result<(ThemeManifest,)> {
        let theme_id = if id == ThemeId::DYNAMIC {
            ThemeId::builtin_dynamic()
        } else {
            ThemeId::new(id).map_err(|e| zbus::fdo::Error::InvalidArgs(e.to_string()))?
        };

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

    /// Returns the JSON list of installed theme IDs.
    pub async fn list_themes(&self) -> zbus::fdo::Result<Vec<ThemeId>> {
        self.service
            .repository()
            .list()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(format!("failed to list themes: {e}")))
    }

    /// Switches the active desktop theme.
    ///
    /// If `id == "rde-dynamic"`, switches to the built-in dynamic theme.
    pub async fn set_active_theme(&self, id: &str) -> zbus::fdo::Result<()> {
        let theme_id = if id == ThemeId::DYNAMIC {
            ThemeId::builtin_dynamic()
        } else {
            ThemeId::new(id).map_err(|e| zbus::fdo::Error::InvalidArgs(e.to_string()))?
        };

        self.service
            .set_active(theme_id)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    /// Switches the desktop appearance between light and dark.
    ///
    /// # Errors
    /// Returns `org.freedesktop.DBus.Error.InvalidArgs` for an unknown mode and
    /// `org.freedesktop.DBus.Error.Failed` when the preference cannot be persisted.
    pub async fn set_mode(&self, mode: &str) -> zbus::fdo::Result<()> {
        // Step 1: Accept only the two appearance values the settings file stores.
        let target = match mode.trim().to_lowercase().as_str() {
            "light" => ThemeMode::Light,
            "dark" => ThemeMode::Dark,
            other => {
                return Err(zbus::fdo::Error::InvalidArgs(format!(
                    "invalid mode '{other}'"
                )));
            }
        };

        // Step 2: Persist and republish through the service.
        self.service
            .set_mode(target)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    /// Updates the seed colors of the built-in dynamic theme (`rde-dynamic`).
    ///
    /// # Parameters
    /// - `primary`: required `#RRGGBB` seed of the primary family and neutral
    ///   surfaces
    /// - `secondary`, `tertiary`, `error`: optional `#RRGGBB` seeds of their
    ///   families; an empty string keeps the currently stored color
    ///
    /// # Behavior
    /// The seeds are validated and persisted to `settings.toml`. When the dynamic
    /// theme is active, every palette is regenerated and `ThemeChanged` is emitted.
    /// Extracting seeds from a wallpaper is the caller's responsibility.
    ///
    /// # Errors
    /// Returns `org.freedesktop.DBus.Error.InvalidArgs` when the primary seed is
    /// empty or any seed is malformed, and `org.freedesktop.DBus.Error.Failed`
    /// when the new seeds cannot be persisted.
    pub async fn update_dynamic_theme(
        &self,
        primary: &str,
        secondary: &str,
        tertiary: &str,
        error: &str,
    ) -> zbus::fdo::Result<()> {
        // Step 1: The primary seed is required; an empty value is a caller error.
        let primary = primary.trim();
        if primary.is_empty() {
            return Err(zbus::fdo::Error::InvalidArgs(
                "a primary seed color is required".to_string(),
            ));
        }

        // Step 2: Treat an empty optional seed as "keep the current color".
        let seed_arg =
            |value: &str| Some(value.trim().to_string()).filter(|value| !value.is_empty());
        let update = DynamicThemeUpdate {
            primary: Some(primary.to_string()),
            secondary: seed_arg(secondary),
            tertiary: seed_arg(tertiary),
            error: seed_arg(error),
        };

        // Step 3: Persist and, when active, republish the dynamic theme.
        self.service
            .update_dynamic_theme(update)
            .await
            .map(|_settings| ())
            .map_err(|err| match err {
                ThemeError::Settings(_) => zbus::fdo::Error::InvalidArgs(err.to_string()),
                other => zbus::fdo::Error::Failed(other.to_string()),
            })
    }

    /// Forces a reload of the active theme manifest and variant files.
    pub async fn reload(&self) -> zbus::fdo::Result<()> {
        self.service
            .reload()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    /// Computes and returns a preview [`crate::domain::resolved::ResolvedTheme`] as JSON without committing.
    pub async fn preview(&self, id: &str, mode: &str, contrast: &str) -> zbus::fdo::Result<String> {
        let theme_id = if id == ThemeId::DYNAMIC {
            ThemeId::builtin_dynamic()
        } else {
            ThemeId::new(id).map_err(|e| zbus::fdo::Error::InvalidArgs(e.to_string()))?
        };

        let mode_val = match mode.to_lowercase().as_str() {
            "light" => ThemeMode::Light,
            "dark" => ThemeMode::Dark,
            other => {
                return Err(zbus::fdo::Error::InvalidArgs(format!(
                    "invalid mode '{other}'"
                )));
            }
        };

        let contrast_val = match contrast.to_lowercase().as_str() {
            "normal" => ContrastLevel::Normal,
            "medium" => ContrastLevel::Medium,
            "high" => ContrastLevel::High,
            other => {
                return Err(zbus::fdo::Error::InvalidArgs(format!(
                    "invalid contrast '{other}'"
                )));
            }
        };

        let resolved = self
            .service
            .preview(&theme_id, mode_val, contrast_val)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(format!("failed to preview theme: {e}")))?;

        serde_json::to_string_pretty(&resolved)
            .map_err(|e| zbus::fdo::Error::Failed(format!("failed to serialize preview: {e}")))
    }

    // =================================
    // SIGNALS
    // =================================

    /// Emitted when the resolved theme has changed and is durable on disk.
    #[zbus(signal)]
    pub async fn theme_changed(
        signal_ctxt: &SignalEmitter<'_>,
        resolved_json: &str,
        generation: u32,
    ) -> zbus::Result<()>;

    /// Emitted when installed themes in the registry change.
    #[zbus(signal)]
    pub async fn theme_list_changed(
        signal_ctxt: &SignalEmitter<'_>,
        ids: &[&str],
    ) -> zbus::Result<()>;

    /// Emitted whenever a reload operation completes.
    #[zbus(signal)]
    pub async fn reloaded(signal_ctxt: &SignalEmitter<'_>) -> zbus::Result<()>;
}

/// Freedesktop XDG Desktop Portal `org.freedesktop.portal.Settings` interface adapter.
pub struct PortalSettingsInterface {
    service: Arc<ThemeService>,
}

impl PortalSettingsInterface {
    /// Constructs a new [`PortalSettingsInterface`].
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
                ThemeMode::Dark => 1,
                ThemeMode::Light => 2,
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
                ThemeMode::Dark => 1,
                ThemeMode::Light => 2,
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

/// Connects service broadcast channels to D-Bus signal emission loops.
pub fn spawn_dbus_signal_broadcaster(connection: zbus::Connection, service: Arc<ThemeService>) {
    let mut theme_changed_rx = service.subscribe_theme_changed();
    let mut reloaded_rx = service.subscribe_reloaded();
    let mut theme_list_rx = service.subscribe_theme_list_changed();

    let conn_clone1 = connection.clone();
    let service_clone = service.clone();
    tokio::spawn(async move {
        while let Ok(resolved) = theme_changed_rx.recv().await {
            let state = service_clone.current_state().await;
            if let Ok(emitter) = SignalEmitter::new(&conn_clone1, THEME_OBJECT_PATH) {
                if let Ok(json) = serde_json::to_string_pretty(&resolved) {
                    let _ = ThemeInterface::theme_changed(&emitter, &json, state.generation).await;
                }
            }

            // Also emit portal SettingChanged signal
            if let Ok(portal_emitter) = SignalEmitter::new(&conn_clone1, PORTAL_OBJECT_PATH) {
                let code: u32 = match state.mode {
                    ThemeMode::Dark => 1,
                    ThemeMode::Light => 2,
                };
                let _ = PortalSettingsInterface::setting_changed(
                    &portal_emitter,
                    "org.freedesktop.appearance",
                    "color-scheme",
                    Variant::U32(code),
                )
                .await;
            }
        }
    });

    let conn_clone2 = connection.clone();
    tokio::spawn(async move {
        while reloaded_rx.recv().await.is_ok() {
            if let Ok(emitter) = SignalEmitter::new(&conn_clone2, THEME_OBJECT_PATH) {
                let _ = ThemeInterface::reloaded(&emitter).await;
            }
        }
    });

    let conn_clone3 = connection;
    tokio::spawn(async move {
        while let Ok(ids) = theme_list_rx.recv().await {
            if let Ok(emitter) = SignalEmitter::new(&conn_clone3, THEME_OBJECT_PATH) {
                let str_ids: Vec<&str> = ids.iter().map(|id| id.as_str()).collect();
                let _ = ThemeInterface::theme_list_changed(&emitter, &str_ids).await;
            }
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        backend::AdapterRegistry, service::ThemeService, theme_store::DiskThemeRepository,
    };
    use zbus::object_server::Interface;

    /// Builds a service backed by throwaway XDG directories.
    async fn temp_service(root: &std::path::Path) -> Arc<ThemeService> {
        let repo = Arc::new(DiskThemeRepository::new(
            root.join("themes"),
            root.join("config"),
            root.join("cache"),
        ));

        let service = ThemeService::startup(
            repo,
            AdapterRegistry::default(),
            root.join("cache").join("current.json"),
            root.join("config").join("settings.toml"),
            root.join("themes"),
        )
        .await
        .expect("theme service must start with empty directories");

        Arc::new(service)
    }

    #[tokio::test]
    async fn exposes_dynamic_theme_contract_in_introspection() {
        let temp = tempfile::tempdir().unwrap();
        let iface = ThemeInterface::new(temp_service(temp.path()).await);

        let mut xml = String::new();
        iface.introspect_to_writer(&mut xml, 0);

        // Methods consumed by the settings app.
        for method in [
            "GetResolvedTheme",
            "GetThemeManifest",
            "ListThemes",
            "SetActiveTheme",
            "SetMode",
            "UpdateDynamicTheme",
            "Reload",
            "Preview",
        ] {
            assert!(xml.contains(method), "missing {method}: {xml}");
        }

        // Properties and signals the settings app subscribes to.
        for name in [
            "ActiveTheme",
            "AvailableThemes",
            "Generation",
            "ThemeChanged",
            "ThemeListChanged",
        ] {
            assert!(xml.contains(name), "missing {name}: {xml}");
        }

        // The dynamic seeds are write-only through `UpdateDynamicTheme`; they are
        // no longer mirrored as individual properties.
        for name in [
            "DynamicPrimary",
            "DynamicSecondary",
            "DynamicTertiary",
            "DynamicError",
        ] {
            assert!(!xml.contains(name), "unexpected {name}: {xml}");
        }
    }

    /// The Flutter client decodes these payloads by signature. Keeping the
    /// literals here in one place makes a struct change fail the build instead
    /// of silently breaking the settings app at runtime.
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
