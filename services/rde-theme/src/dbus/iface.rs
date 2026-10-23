//! # D-Bus Object Interface Definition (`org.rde.Theme`)
//!
//! Public D-Bus surface of the theme service. Every call is a thin adapter over
//! [`ThemeStore`]: the store owns validation and persistence, this module maps
//! results onto D-Bus types, FDO errors, and signals.
//!
//! ## Properties
//! - `Version` (s, read-only): service version
//! - `CurrentTheme` (s, read-only): identifier of the active theme
//! - `InstalledThemes` (as, read-only): identifiers of installed themes
//! - `ColorScheme` (s, read-write): `light` or `dark`
//! - `SourceColor` (s, read-only): source color of the active theme
//!
//! ## Methods
//! - `SetTheme(name: s)`: activate an installed theme
//! - `CreateTheme(name: s, source_color: s)`: create a theme from a seed color
//! - `DeleteTheme(name: s)`: remove a non-active theme
//! - `SetSourceColor(color: s)`: re-seed the active theme
//! - `ToggleColorScheme() -> s`: switch light/dark, returning the new scheme
//! - `GetPalette(name: s, scheme: s) -> a{ss}`: palette role map in `#RRGGBB`
//! - `GetThemeInfo(name: s) -> a{ss}`: manifest metadata for theme pickers
//! - `Reload()`: re-read the database after external changes
//!
//! ## Signals
//! - `ThemeChanged(theme: s, color_scheme: s)`: active theme changed
//! - `ColorSchemeChanged(color_scheme: s)`: light/dark preference changed
//! - `PaletteChanged(theme: s, source_color: s)`: active theme was re-seeded
//! - `InstalledThemesChanged(themes: as)`: installed theme list changed
//!
//! ## Side Effects
//! Every successful theme or scheme change is also written to the Qt and KDE
//! configuration through [`crate::backend::qt`]. That step is best effort: a
//! failure is logged and never turns a persisted theme change into a D-Bus
//! error.
//!
//! ## Related
//! - [`crate::theme_store::ThemeStore`][]: authoritative state
//! - [`crate::domain::theme::ColorScheme`][]: accepted scheme values
//! - [`crate::app`][]: publishes this object on the session bus
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::{collections::BTreeMap, sync::Arc};

use rde_core::errors::RdeError;
use tracing::{debug, info, warn};
use zbus::{interface, object_server::SignalEmitter};

use crate::{
    backend::qt,
    domain::theme::{ColorScheme, ThemeId},
    theme_store::ThemeStore,
};

/// D-Bus object implementing the `org.rde.Theme` interface.
///
/// Holds a shared handle to the theme store; the store provides interior
/// mutability, so D-Bus calls can take `&self` and emit signals after the lock
/// has been released.
pub struct ThemeInterface {
    /// Theme database shared with the rest of the service.
    store: Arc<ThemeStore>,
}

impl ThemeInterface {
    /// Creates the interface around an initialized theme store.
    ///
    /// # Parameters
    /// - `store`: database loaded by [`crate::app::App`]
    pub fn new(store: Arc<ThemeStore>) -> Self {
        Self { store }
    }

    /// Emits the standard property and custom signals for an active theme
    /// change.
    async fn emit_active_theme(&self, emitter: &SignalEmitter<'_>) {
        let theme = self
            .store
            .current_theme()
            .map(|theme| theme.to_string())
            .unwrap_or_default();
        let color_scheme = self.store.color_scheme().to_string();

        if let Err(error) = self.current_theme_changed(emitter).await {
            warn!(%error, "failed to emit the CurrentTheme property change");
        }
        if let Err(error) = self.source_color_changed(emitter).await {
            warn!(%error, "failed to emit the SourceColor property change");
        }
        if let Err(error) = Self::theme_changed(emitter, theme, color_scheme).await {
            warn!(%error, "failed to emit the ThemeChanged signal");
        }
    }

    /// Emits the standard property and custom signals for a scheme change.
    async fn emit_scheme(&self, emitter: &SignalEmitter<'_>, color_scheme: ColorScheme) {
        if let Err(error) = self.color_scheme_changed(emitter).await {
            warn!(%error, "failed to emit the ColorScheme property change");
        }
        if let Err(error) = Self::scheme_changed(emitter, color_scheme.to_string()).await {
            warn!(%error, "failed to emit the ColorSchemeChanged signal");
        }
    }

    /// Applies the active theme to the Qt and KDE configuration files.
    ///
    /// Qt integration is best effort: a failure is logged and the theme change
    /// is still reported to D-Bus clients, because the theme database is the
    /// source of truth and a missing Qt installation must not block it.
    fn apply_qt(&self) {
        let theme = match self.store.active_theme() {
            Ok(theme) => theme,
            Err(error) => {
                warn!(%error, "Skipping Qt theme application: no resolvable active theme");
                return;
            }
        };

        match qt::apply(&theme) {
            Ok(report) if report.is_complete() => debug!(
                theme = %theme.manifest.name,
                scheme = %theme.color_scheme,
                written = report.written.len(),
                "Qt color scheme applied"
            ),
            Ok(report) => warn!(
                theme = %theme.manifest.name,
                failures = report.failures.len(),
                "Qt color scheme applied with warnings"
            ),
            Err(error) => warn!(%error, "Unable to apply the Qt color scheme"),
        }
    }

    /// Emits the installed-theme property change and custom signal.
    async fn emit_installed_themes(&self, emitter: &SignalEmitter<'_>) {
        let themes: Vec<String> = self
            .store
            .installed_themes()
            .into_iter()
            .map(|theme| theme.to_string())
            .collect();

        if let Err(error) = self.installed_themes_changed(emitter).await {
            warn!(%error, "failed to emit the InstalledThemes property change");
        }
        if let Err(error) = Self::themes_installed(emitter, themes).await {
            warn!(%error, "failed to emit the InstalledThemesChanged signal");
        }
    }
}

#[interface(name = "org.rde.Theme")]
impl ThemeInterface {
    // =================================
    // PROPERTIES
    // =================================

    /// Service version string.
    ///
    /// # Returns
    /// The package version from `CARGO_PKG_VERSION` (e.g. `0.1.0`).
    #[zbus(property)]
    pub fn version(&self) -> String {
        env!("CARGO_PKG_VERSION").to_string()
    }

    /// Identifier of the currently active theme.
    ///
    /// # Returns
    /// The theme identifier, for example `default` or `ocean`.
    #[zbus(property)]
    pub fn current_theme(&self) -> String {
        self.store
            .current_theme()
            .map(|theme| theme.to_string())
            .unwrap_or_default()
    }

    /// Identifiers of every installed theme, sorted.
    ///
    /// # Returns
    /// The installed theme names.
    #[zbus(property)]
    pub fn installed_themes(&self) -> Vec<String> {
        self.store
            .installed_themes()
            .into_iter()
            .map(|theme| theme.to_string())
            .collect()
    }

    /// Active light/dark appearance (`light` or `dark`).
    ///
    /// # Returns
    /// The active color scheme.
    #[zbus(property)]
    pub fn color_scheme(&self) -> String {
        self.store.color_scheme().to_string()
    }

    /// Sets the light/dark appearance.
    ///
    /// # Arguments
    /// - `scheme`: `light` or `dark` (case-insensitive)
    ///
    /// # Errors
    /// Returns `org.freedesktop.DBus.Error.InvalidArgs` when the value is not a
    /// valid scheme, and `org.freedesktop.DBus.Error.IOError` when the registry
    /// cannot be persisted.
    ///
    /// # Signals
    /// Emits `ColorSchemeChanged`, and the standard `PropertiesChanged` signal
    /// after a successful update.
    ///
    /// # Side Effects
    /// Applies the new scheme to the Qt and KDE color schemes.
    #[zbus(property)]
    pub async fn set_color_scheme(
        &self,
        scheme: String,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        debug!(scheme = %scheme, "SetColorScheme requested");

        // Step 1: Validate the requested scheme before touching the store.
        let color_scheme = parse_scheme(&scheme)?;

        // Step 2: Persist the preference.
        self.store
            .set_color_scheme(color_scheme)
            .map_err(to_fdo_error)?;

        // Step 3: Mirror the scheme into the Qt/KDE configuration.
        self.apply_qt();

        info!(scheme = %color_scheme, "color scheme updated over D-Bus");

        // Step 4: Notify subscribers of the semantic change.
        self.emit_scheme(&emitter, color_scheme).await;
        Ok(())
    }

    /// Source color of the active theme in `#RRGGBB` form.
    ///
    /// # Returns
    /// The seed color used to derive the active theme's palettes.
    ///
    /// # Errors
    /// Returns an FDO error when no theme is active.
    #[zbus(property)]
    pub fn source_color(&self) -> zbus::fdo::Result<String> {
        self.store.source_color().map_err(to_fdo_error)
    }

    // =================================
    // METHODS
    // =================================

    /// Activates an installed theme.
    ///
    /// # Arguments
    /// - `theme`: identifier of an installed theme
    ///
    /// # Errors
    /// Returns `org.freedesktop.DBus.Error.FileNotFound` when the theme is not
    /// installed and `org.freedesktop.DBus.Error.IOError` when the registry
    /// cannot be persisted.
    ///
    /// # Signals
    /// Emits `ThemeChanged`, the `CurrentTheme` and `SourceColor` property
    /// changes, and `PropertiesChanged`.
    ///
    /// # Side Effects
    /// Applies the new theme to the Qt and KDE color schemes.
    #[zbus(name = "SetTheme")]
    pub async fn set_theme(
        &self,
        theme: String,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        debug!(theme = %theme, "SetTheme requested");

        // Step 1: Validate the identifier and activate it.
        let theme = parse_theme(&theme)?;
        self.store.set_theme(&theme).map_err(to_fdo_error)?;

        // Step 2: Apply the palette to Qt and KDE.
        self.apply_qt();

        info!(theme = %theme, "active theme updated over D-Bus");

        // Step 3: Signal the new active theme.
        self.emit_active_theme(&emitter).await;
        Ok(())
    }

    /// Creates a new theme from a source color.
    ///
    /// The theme is installed but not activated; call `SetTheme` afterwards to
    /// apply it.
    ///
    /// # Arguments
    /// - `name`: new theme identifier (letters, digits, `-`, `_`, `.`)
    /// - `source_color`: seed color as `#RGB`, `RGB`, `#RRGGBB`, or `RRGGBB`
    ///
    /// # Errors
    /// Returns `org.freedesktop.DBus.Error.InvalidArgs` for an invalid name or
    /// color, `org.freedesktop.DBus.Error.FileExists` when the theme already
    /// exists, and `org.freedesktop.DBus.Error.IOError` on write failures.
    ///
    /// # Signals
    /// Emits `InstalledThemesChanged` and the `InstalledThemes` property change.
    #[zbus(name = "CreateTheme")]
    pub async fn create_theme(
        &self,
        name: String,
        source_color: String,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        debug!(theme = %name, source_color = %source_color, "CreateTheme requested");

        // Step 1: Validate the identifier, then let the store generate and
        // persist the manifest from the seed color.
        let theme = parse_theme(&name)?;
        let manifest = self
            .store
            .create_theme(theme, &source_color)
            .map_err(to_fdo_error)?;

        info!(
            theme = %manifest.name,
            source_color = %manifest.source_color,
            "theme created over D-Bus"
        );

        // Step 2: Advertise the new theme.
        self.emit_installed_themes(&emitter).await;
        Ok(())
    }

    /// Deletes an installed theme.
    ///
    /// # Arguments
    /// - `theme`: identifier of an installed, non-active theme
    ///
    /// # Errors
    /// Returns `org.freedesktop.DBus.Error.FileNotFound` when the theme is not
    /// installed, `org.freedesktop.DBus.Error.InvalidArgs` when it is the active
    /// theme, and `org.freedesktop.DBus.Error.IOError` on write failures.
    ///
    /// # Signals
    /// Emits `InstalledThemesChanged` and the `InstalledThemes` property change.
    #[zbus(name = "DeleteTheme")]
    pub async fn delete_theme(
        &self,
        theme: String,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        debug!(theme = %theme, "DeleteTheme requested");

        // Step 1: Validate and remove the theme.
        let theme = parse_theme(&theme)?;
        self.store.delete_theme(&theme).map_err(to_fdo_error)?;

        info!(theme = %theme, "theme deleted over D-Bus");

        // Step 2: Advertise the updated list.
        self.emit_installed_themes(&emitter).await;
        Ok(())
    }

    /// Re-seeds the active theme with a new source color.
    ///
    /// The manifest is updated and the palette is regenerated on the next
    /// `GetPalette` call, so applications can preview both schemes.
    ///
    /// # Arguments
    /// - `color`: new seed color in any supported hexadecimal form
    ///
    /// # Errors
    /// Returns `org.freedesktop.DBus.Error.InvalidArgs` for an invalid color,
    /// `org.freedesktop.DBus.Error.FileNotFound` when no theme is active, and
    /// `org.freedesktop.DBus.Error.IOError` on write failures.
    ///
    /// # Signals
    /// Emits `PaletteChanged`, the `SourceColor` property change, and
    /// `PropertiesChanged`.
    ///
    /// # Side Effects
    /// Regenerates the Qt and KDE color schemes from the new palette.
    #[zbus(name = "SetSourceColor")]
    pub async fn set_source_color(
        &self,
        color: String,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        debug!(color = %color, "SetSourceColor requested");

        // Step 1: Update the active manifest.
        let manifest = self.store.set_source_color(&color).map_err(to_fdo_error)?;

        // Step 2: Regenerate the Qt/KDE color schemes from the new palette.
        self.apply_qt();

        info!(
            theme = %manifest.name,
            source_color = %manifest.source_color,
            "active theme re-seeded over D-Bus"
        );

        // Step 3: Signal the regenerated palette.
        if let Err(error) = self.source_color_changed(&emitter).await {
            warn!(%error, "failed to emit the SourceColor property change");
        }
        if let Err(error) =
            Self::palette_changed(&emitter, manifest.name.to_string(), manifest.source_color).await
        {
            warn!(%error, "failed to emit the PaletteChanged signal");
        }
        Ok(())
    }

    /// Switches the color scheme between light and dark.
    ///
    /// # Returns
    /// The newly active scheme (`light` or `dark`).
    ///
    /// # Errors
    /// Returns `org.freedesktop.DBus.Error.IOError` when the preference cannot
    /// be persisted.
    ///
    /// # Signals
    /// Emits `ColorSchemeChanged` and the `ColorScheme` property change.
    ///
    /// # Side Effects
    /// Applies the new scheme to the Qt and KDE color schemes.
    #[zbus(name = "ToggleColorScheme")]
    pub async fn toggle_color_scheme(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<String> {
        debug!("ToggleColorScheme requested");

        // Step 1: Flip and persist the scheme.
        let color_scheme = self.store.toggle_color_scheme().map_err(to_fdo_error)?;

        // Step 2: Apply the new scheme to Qt and KDE.
        self.apply_qt();

        info!(scheme = %color_scheme, "color scheme toggled over D-Bus");

        // Step 3: Notify subscribers.
        self.emit_scheme(&emitter, color_scheme).await;
        Ok(color_scheme.to_string())
    }

    /// Returns the palette of a theme for a specific scheme.
    ///
    /// This lets callers preview the inactive scheme without switching the
    /// system preference.
    ///
    /// # Arguments
    /// - `theme`: installed theme identifier
    /// - `scheme`: `light` or `dark` (case-insensitive)
    ///
    /// # Returns
    /// A map from Material 3 role name (e.g. `primary_container`) to
    /// `#RRGGBB`.
    ///
    /// # Errors
    /// Returns `org.freedesktop.DBus.Error.FileNotFound` when the theme is not
    /// installed and `org.freedesktop.DBus.Error.InvalidArgs` for an invalid
    /// scheme or a manifest with an invalid source color.
    #[zbus(name = "GetPalette")]
    pub fn get_palette(
        &self,
        theme: String,
        scheme: String,
    ) -> zbus::fdo::Result<BTreeMap<String, String>> {
        debug!(theme = %theme, scheme = %scheme, "GetPalette requested");

        let theme = parse_theme(&theme)?;
        let color_scheme = parse_scheme(&scheme)?;

        self.store
            .palette(&theme, color_scheme)
            .map(|palette| palette.role_map())
            .map_err(to_fdo_error)
    }

    /// Returns the manifest metadata of an installed theme.
    ///
    /// Intended for theme pickers that need names, descriptions, and source
    /// colors without reading the filesystem.
    ///
    /// # Arguments
    /// - `theme`: installed theme identifier
    ///
    /// # Returns
    /// A map with `name`, `display_name`, `description`, `author`, `license`,
    /// `version`, `source_color`, and `manifest_path`.
    ///
    /// # Errors
    /// Returns `org.freedesktop.DBus.Error.FileNotFound` when the theme is not
    /// installed.
    #[zbus(name = "GetThemeInfo")]
    pub fn get_theme_info(&self, theme: String) -> zbus::fdo::Result<BTreeMap<String, String>> {
        debug!(theme = %theme, "GetThemeInfo requested");

        let theme = parse_theme(&theme)?;
        let manifest = self.store.manifest(&theme).map_err(to_fdo_error)?;

        let mut info = BTreeMap::new();
        info.insert("name".to_string(), manifest.name.to_string());
        info.insert("display_name".to_string(), manifest.display_name);
        info.insert("description".to_string(), manifest.description);
        info.insert("author".to_string(), manifest.author.unwrap_or_default());
        info.insert("license".to_string(), manifest.license.unwrap_or_default());
        info.insert("version".to_string(), manifest.version);
        info.insert("source_color".to_string(), manifest.source_color);
        info.insert(
            "manifest_path".to_string(),
            self.store
                .paths()
                .manifest_file(&manifest.name)
                .display()
                .to_string(),
        );

        Ok(info)
    }

    /// Reloads the theme database from disk.
    ///
    /// Use after editing `themes.toml` or copying a theme directory by hand.
    ///
    /// # Errors
    /// Returns an FDO error when the database cannot be read or repaired.
    ///
    /// # Signals
    /// Emits `ThemeChanged`, `ColorSchemeChanged`, `InstalledThemesChanged`, and
    /// the corresponding property changes.
    ///
    /// # Side Effects
    /// Re-applies the reloaded theme to the Qt and KDE color schemes.
    #[zbus(name = "Reload")]
    pub async fn reload(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        info!("Reload requested over D-Bus");

        // Step 1: Re-read and reconcile the database.
        self.store.reload().map_err(to_fdo_error)?;

        // Step 2: Re-apply the reloaded theme to Qt and KDE.
        self.apply_qt();

        // Step 3: Re-publish every property that may have changed.
        self.emit_installed_themes(&emitter).await;
        self.emit_active_theme(&emitter).await;
        self.emit_scheme(&emitter, self.store.color_scheme()).await;
        Ok(())
    }

    // =================================
    // SIGNALS
    // =================================

    /// Emitted when the active theme changes.
    ///
    /// # Arguments
    /// - `theme`: identifier of the active theme
    /// - `color_scheme`: active scheme (`light` or `dark`)
    #[zbus(signal, name = "ThemeChanged")]
    pub async fn theme_changed(
        signal_emitter: &SignalEmitter<'_>,
        theme: String,
        color_scheme: String,
    ) -> zbus::Result<()>;

    /// Emitted when the light/dark preference changes.
    ///
    /// # Arguments
    /// - `color_scheme`: newly active scheme (`light` or `dark`)
    #[zbus(signal, name = "ColorSchemeChanged")]
    pub async fn scheme_changed(
        signal_emitter: &SignalEmitter<'_>,
        color_scheme: String,
    ) -> zbus::Result<()>;

    /// Emitted when the active theme is re-seeded with a new source color.
    ///
    /// # Arguments
    /// - `theme`: identifier of the active theme
    /// - `source_color`: new source color in `#RRGGBB` form
    #[zbus(signal, name = "PaletteChanged")]
    pub async fn palette_changed(
        signal_emitter: &SignalEmitter<'_>,
        theme: String,
        source_color: String,
    ) -> zbus::Result<()>;

    /// Emitted when a theme is installed or removed.
    ///
    /// # Arguments
    /// - `themes`: identifiers of every installed theme, sorted
    #[zbus(signal, name = "InstalledThemesChanged")]
    pub async fn themes_installed(
        signal_emitter: &SignalEmitter<'_>,
        themes: Vec<String>,
    ) -> zbus::Result<()>;
}

/// Parses and validates a theme identifier received over D-Bus.
///
/// # Errors
/// Returns `org.freedesktop.DBus.Error.InvalidArgs` when the identifier is not
/// valid.
fn parse_theme(value: &str) -> zbus::fdo::Result<ThemeId> {
    ThemeId::new(value).map_err(to_fdo_error)
}

/// Parses a `light`/`dark` scheme received over D-Bus.
///
/// # Errors
/// Returns `org.freedesktop.DBus.Error.InvalidArgs` for any other value.
fn parse_scheme(value: &str) -> zbus::fdo::Result<ColorScheme> {
    value.parse::<ColorScheme>().map_err(to_fdo_error)
}

/// Maps a domain error onto the closest FDO D-Bus error.
///
/// # Parameters
/// - `error`: error produced by the store or the domain layer
fn to_fdo_error(error: RdeError) -> zbus::fdo::Error {
    let message = error.to_string();

    match error {
        RdeError::NotFound(_) => zbus::fdo::Error::FileNotFound(message),
        RdeError::AlreadyExists(_) => zbus::fdo::Error::FileExists(message),
        RdeError::InvalidValue(_) | RdeError::InvalidConfig(_) => {
            zbus::fdo::Error::InvalidArgs(message)
        }
        RdeError::Io(_) => zbus::fdo::Error::IOError(message),
        RdeError::PermissionDenied(_) => zbus::fdo::Error::AccessDenied(message),
        other => zbus::fdo::Error::Failed(other.to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn invalid_identifiers_map_to_invalid_args() {
        let error = parse_theme("../escape").expect_err("path traversal must be rejected");
        assert!(matches!(error, zbus::fdo::Error::InvalidArgs(_)));
    }

    #[test]
    fn invalid_schemes_map_to_invalid_args() {
        let error = parse_scheme("sepia").expect_err("unknown scheme");
        assert!(matches!(error, zbus::fdo::Error::InvalidArgs(_)));
        assert_eq!(
            parse_scheme("DARK").expect("scheme parsing is case-insensitive"),
            ColorScheme::Dark
        );
    }

    #[test]
    fn domain_errors_map_to_fdo_errors() {
        assert!(matches!(
            to_fdo_error(RdeError::NotFound("missing".to_string())),
            zbus::fdo::Error::FileNotFound(_)
        ));
        assert!(matches!(
            to_fdo_error(RdeError::AlreadyExists("duplicate".to_string())),
            zbus::fdo::Error::FileExists(_)
        ));
        assert!(matches!(
            to_fdo_error(RdeError::InvalidValue("bad".to_string())),
            zbus::fdo::Error::InvalidArgs(_)
        ));
        assert!(matches!(
            to_fdo_error(RdeError::PermissionDenied("denied".to_string())),
            zbus::fdo::Error::AccessDenied(_)
        ));
        assert!(matches!(
            to_fdo_error(RdeError::Internal("boom".to_string())),
            zbus::fdo::Error::Failed(_)
        ));
    }
}
