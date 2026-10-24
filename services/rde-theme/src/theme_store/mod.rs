//! # Theme Store
//!
//! Owns the in-memory theme database, persists changes atomically, and reconciles
//! the registry with the manifests on disk.

use std::{
    collections::BTreeMap,
    sync::{RwLock, RwLockReadGuard, RwLockWriteGuard},
};

use rde_core::errors::{RdeError, RdeResult};
use tracing::{debug, info, warn};

mod disk;

use crate::{
    backend::{MaterialBackend, ThemeBackend},
    constants::REGISTRY_SCHEMA_VERSION,
    domain::{
        color::normalize_hex_color,
        palette::Palette,
        theme::{ColorScheme, Theme, ThemeId, ThemeManifest},
        theme_config::ThemeRegistry,
    },
    paths::ThemePaths,
};

/// In-memory mirror of the theme database.
struct StoreState {
    /// Session state persisted in `themes.toml`.
    registry: ThemeRegistry,

    /// Installed manifests keyed by identifier, ordered for stable output.
    manifests: BTreeMap<ThemeId, ThemeManifest>,
}

/// Thread-safe façade over the theme database.
///
/// All methods are synchronous and complete their file I/O before returning, so
/// the D-Bus interface can await signal emission afterwards without holding a
/// lock. Reads take a shared lock; mutations take an exclusive lock.
pub struct ThemeStore {
    /// Filesystem layout of the database.
    paths: ThemePaths,

    /// Color engine used to resolve manifests into palettes.
    backend: Box<dyn ThemeBackend + Send + Sync>,

    /// Current registry and manifest mirror.
    state: RwLock<StoreState>,
}

impl ThemeStore {
    /// Opens the theme database, creating and repairing it as needed.
    ///
    /// # Workflow
    /// 1. Create the root and `themes/` directories
    /// 2. Load `themes.toml`; a corrupt file is moved to `themes.toml.invalid`
    /// 3. Scan `themes/*/theme.toml` and load every valid manifest
    /// 4. Seed the built-in default theme when no manifest exists
    /// 5. Reconcile the installed list and active theme against the manifests
    /// 6. Persist the registry when reconciliation changed anything
    ///
    /// # Parameters
    /// - `paths`: resolved database layout
    ///
    /// # Errors
    /// Returns [`RdeError::Io`] when the database cannot be created or written
    /// and [`RdeError::InvalidConfig`] when the default theme cannot be
    /// generated.
    pub fn open(paths: ThemePaths) -> RdeResult<Self> {
        Self::open_with_backend(paths, Box::new(MaterialBackend))
    }

    /// Opens the theme database with an explicit color engine.
    ///
    /// The default [`ThemeStore::open`] uses [`MaterialBackend`]; this variant
    /// exists so alternative engines can be supplied without touching storage.
    ///
    /// # Parameters
    /// - `paths`: resolved database layout
    /// - `backend`: palette engine used to resolve themes
    ///
    /// # Errors
    /// Returns the same errors as [`ThemeStore::open`].
    pub fn open_with_backend(
        paths: ThemePaths,
        backend: Box<dyn ThemeBackend + Send + Sync>,
    ) -> RdeResult<Self> {
        let state = load_state(&paths)?;

        info!(
            root = %paths.root().display(),
            current = state
                .registry
                .current_theme
                .as_ref()
                .map(ThemeId::as_str)
                .unwrap_or_default(),
            installed = state.registry.installed.len(),
            "theme database ready"
        );

        Ok(Self {
            paths,
            backend,
            state: RwLock::new(state),
        })
    }

    /// Returns the filesystem layout backing this store.
    pub fn paths(&self) -> &ThemePaths {
        &self.paths
    }

    /// Returns the identifier of the active theme.
    ///
    /// # Returns
    /// `None` only for an empty database, which [`ThemeStore::open`] prevents
    /// by seeding the default theme.
    pub fn current_theme(&self) -> Option<ThemeId> {
        self.read_state().registry.current_theme.clone()
    }

    /// Returns the identifiers of all installed themes, sorted.
    pub fn installed_themes(&self) -> Vec<ThemeId> {
        self.read_state().registry.installed.clone()
    }

    /// Returns the active light/dark appearance.
    pub fn color_scheme(&self) -> ColorScheme {
        self.read_state().registry.color_scheme
    }

    /// Returns the source color of the active theme.
    ///
    /// # Errors
    /// Returns [`RdeError::NotFound`] when no theme is active.
    pub fn source_color(&self) -> RdeResult<String> {
        let state = self.read_state();

        active_manifest(&state).map(|manifest| manifest.source_color.clone())
    }

    /// Returns the manifest of an installed theme.
    ///
    /// # Errors
    /// Returns [`RdeError::NotFound`] when the theme is not installed.
    pub fn manifest(&self, theme: &ThemeId) -> RdeResult<ThemeManifest> {
        self.read_state()
            .manifests
            .get(theme)
            .cloned()
            .ok_or_else(|| not_installed(theme))
    }

    /// Resolves the active theme with a palette for the active scheme.
    ///
    /// # Errors
    /// Returns [`RdeError::NotFound`] when no theme is active and
    /// [`RdeError::InvalidValue`] when the manifest's source color is invalid.
    pub fn active_theme(&self) -> RdeResult<Theme> {
        let state = self.read_state();
        let manifest = active_manifest(&state)?;

        self.backend.resolve(manifest, state.registry.color_scheme)
    }

    /// Generates the palette of an installed theme for a specific scheme.
    ///
    /// # Parameters
    /// - `theme`: installed theme identifier
    /// - `color_scheme`: scheme to generate, independent of the active scheme
    ///
    /// # Errors
    /// Returns [`RdeError::NotFound`] when the theme is not installed and
    /// [`RdeError::InvalidValue`] when its source color is invalid.
    pub fn palette(&self, theme: &ThemeId, color_scheme: ColorScheme) -> RdeResult<Palette> {
        let manifest = self.manifest(theme)?;

        self.backend.palette(&manifest.source_color, color_scheme)
    }

    /// Activates an installed theme and persists the choice.
    ///
    /// # Errors
    /// Returns [`RdeError::NotFound`] when the theme is not installed and
    /// [`RdeError::Io`] when the registry cannot be written. A failed write
    /// restores the previously active theme.
    pub fn set_theme(&self, theme: &ThemeId) -> RdeResult<()> {
        let mut state = self.write_state();

        if !state.manifests.contains_key(theme) {
            return Err(not_installed(theme));
        }
        if state.registry.current_theme.as_ref() == Some(theme) {
            debug!(theme = %theme, "theme is already active");
            return Ok(());
        }

        // Step 1: Apply in memory, then persist; roll back when the write fails
        // so the reported state never diverges from the file.
        let previous = state.registry.current_theme.replace(theme.clone());
        if let Err(error) = self.persist_registry(&state) {
            state.registry.current_theme = previous;
            return Err(error);
        }

        info!(theme = %theme, "active theme changed");
        Ok(())
    }

    /// Changes the active light/dark appearance and persists it.
    ///
    /// # Errors
    /// Returns [`RdeError::Io`] when the registry cannot be written, restoring
    /// the previous scheme.
    pub fn set_color_scheme(&self, color_scheme: ColorScheme) -> RdeResult<()> {
        let mut state = self.write_state();

        if state.registry.color_scheme == color_scheme {
            return Ok(());
        }

        let previous = state.registry.color_scheme;
        state.registry.color_scheme = color_scheme;

        if let Err(error) = self.persist_registry(&state) {
            state.registry.color_scheme = previous;
            return Err(error);
        }

        info!(scheme = %color_scheme, "color scheme changed");
        Ok(())
    }

    /// Switches between light and dark and returns the new scheme.
    ///
    /// # Errors
    /// Returns the error from [`ThemeStore::set_color_scheme`].
    pub fn toggle_color_scheme(&self) -> RdeResult<ColorScheme> {
        let next = self.color_scheme().toggled();
        self.set_color_scheme(next)?;

        Ok(next)
    }

    /// Creates a new theme from a source color.
    ///
    /// The theme is installed but not activated; callers that want to apply it
    /// call [`ThemeStore::set_theme`] afterwards. The manifest is written
    /// before the registry is updated, and the directory is removed again if
    /// the registry cannot be persisted.
    ///
    /// # Parameters
    /// - `theme`: validated identifier, also used as the directory name
    /// - `source_color`: seed color in any supported hexadecimal form
    ///
    /// # Returns
    /// The manifest that was written to disk.
    ///
    /// # Errors
    /// Returns [`RdeError::AlreadyExists`] when the theme is installed,
    /// [`RdeError::InvalidValue`] when the source color is invalid, and
    /// [`RdeError::Io`] when the database cannot be written.
    pub fn create_theme(&self, theme: ThemeId, source_color: &str) -> RdeResult<ThemeManifest> {
        let manifest = ThemeManifest::new(theme, source_color)?;
        let mut state = self.write_state();

        if state.manifests.contains_key(&manifest.name) {
            return Err(RdeError::AlreadyExists(format!(
                "theme '{}' is already installed",
                manifest.name
            )));
        }

        // Step 1: Write the manifest so the theme is recoverable even if the
        // registry update below fails.
        disk::write_manifest(&self.paths.manifest_file(&manifest.name), &manifest)?;

        // Step 2: Update the registry in memory, remembering the previous
        // values for a rollback.
        let previous_installed = state.registry.installed.clone();
        let previous_current = state.registry.current_theme.clone();
        let mut installed = previous_installed.clone();
        installed.push(manifest.name.clone());
        installed.sort();
        state.registry.installed = installed;
        state
            .manifests
            .insert(manifest.name.clone(), manifest.clone());

        // Step 3: Persist; on failure remove the new manifest and roll back.
        if let Err(error) = self.persist_registry(&state) {
            state.registry.installed = previous_installed;
            state.registry.current_theme = previous_current;
            state.manifests.remove(&manifest.name);
            if let Err(cleanup) = disk::remove_theme_dir(&self.paths, &manifest.name) {
                warn!(theme = %manifest.name, %cleanup, "failed to clean up a theme after a failed registry write");
            }
            return Err(error);
        }

        info!(
            theme = %manifest.name,
            source_color = %manifest.source_color,
            "theme created"
        );
        Ok(manifest)
    }

    /// Deletes an installed theme.
    ///
    /// # Errors
    /// Returns [`RdeError::NotFound`] when the theme is not installed,
    /// [`RdeError::InvalidValue`] when it is the active theme, and
    /// [`RdeError::Io`] when the directory or registry cannot be written.
    pub fn delete_theme(&self, theme: &ThemeId) -> RdeResult<()> {
        let mut state = self.write_state();
        let manifest = state
            .manifests
            .get(theme)
            .cloned()
            .ok_or_else(|| not_installed(theme))?;

        // Step 1: The active theme must stay installed so a palette always
        // exists, even if no theme is ever applied at boot.
        if state.registry.current_theme.as_ref() == Some(theme) {
            return Err(RdeError::InvalidValue(format!(
                "theme '{theme}' is active; switch to another theme before deleting it"
            )));
        }

        // Step 2: Remove the directory first; the registry is reconciled on the
        // next startup, so a failed registry write cannot resurrect the theme.
        disk::remove_theme_dir(&self.paths, theme)?;

        let previous_installed = state.registry.installed.clone();
        state.manifests.remove(theme);
        state
            .registry
            .installed
            .retain(|installed| installed != theme);

        if let Err(error) = self.persist_registry(&state) {
            state.manifests.insert(theme.clone(), manifest);
            state.registry.installed = previous_installed;
            return Err(error);
        }

        info!(theme = %theme, "theme deleted");
        Ok(())
    }

    /// Updates the source color of the active theme and regenerates its
    /// palette.
    ///
    /// # Parameters
    /// - `source_color`: new seed color in any supported hexadecimal form
    ///
    /// # Returns
    /// The updated manifest.
    ///
    /// # Errors
    /// Returns [`RdeError::NotFound`] when no theme is active,
    /// [`RdeError::InvalidValue`] when the color is invalid, and
    /// [`RdeError::Io`] when the manifest cannot be written.
    pub fn set_source_color(&self, source_color: &str) -> RdeResult<ThemeManifest> {
        let normalized = normalize_hex_color(source_color)?;
        let mut state = self.write_state();

        let theme = state
            .registry
            .current_theme
            .clone()
            .ok_or_else(|| RdeError::NotFound("no active theme".to_string()))?;
        let manifest = state
            .manifests
            .get(&theme)
            .cloned()
            .ok_or_else(|| not_installed(&theme))?;

        if manifest.source_color == normalized {
            return Ok(manifest);
        }

        // Step 1: Persist the new definition before exposing it in memory.
        let updated = ThemeManifest {
            source_color: normalized,
            ..manifest
        };
        disk::write_manifest(&self.paths.manifest_file(&theme), &updated)?;
        state.manifests.insert(theme.clone(), updated.clone());

        info!(
            theme = %theme,
            source_color = %updated.source_color,
            "theme source color updated"
        );
        Ok(updated)
    }

    /// Reloads the database from disk, reconciling it with the manifests.
    ///
    /// Useful after a manual edit of `themes.toml` or after installing a theme
    /// by copying a directory.
    ///
    /// # Errors
    /// Returns the same errors as [`ThemeStore::open`].
    pub fn reload(&self) -> RdeResult<()> {
        let state = load_state(&self.paths)?;
        *self.write_state() = state;

        info!("theme database reloaded from disk");
        Ok(())
    }

    /// Persists the registry held by the given state.
    fn persist_registry(&self, state: &StoreState) -> RdeResult<()> {
        disk::write_registry(&self.paths.registry_file(), &state.registry)
    }

    /// Acquires a shared lock, recovering the state if a writer panicked.
    fn read_state(&self) -> RwLockReadGuard<'_, StoreState> {
        self.state
            .read()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    /// Acquires an exclusive lock, recovering the state if a writer panicked.
    fn write_state(&self) -> RwLockWriteGuard<'_, StoreState> {
        self.state
            .write()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }
}

/// Loads the registry and manifests, seeding and reconciling them as needed.
///
/// # Errors
/// Returns [`RdeError::Io`] when the database cannot be read or written and
/// [`RdeError::InvalidConfig`] when the default theme cannot be generated.
fn load_state(paths: &ThemePaths) -> RdeResult<StoreState> {
    paths.ensure()?;

    // Step 1: Load the registry. A missing file is expected on first start; an
    // unparsable one is moved aside so the user can inspect it later.
    let mut needs_persist = false;
    let loaded = match disk::read_registry(&paths.registry_file()) {
        Ok(Some(registry)) => registry,
        Ok(None) => {
            debug!("theme registry does not exist yet; a new one will be written");
            needs_persist = true;
            ThemeRegistry::default()
        }
        Err(error) => {
            warn!(%error, "theme registry could not be loaded; rebuilding it from the theme manifests");
            match disk::quarantine(&paths.registry_file()) {
                Ok(path) => warn!(path = %path.display(), "invalid theme registry moved aside"),
                Err(error) => {
                    warn!(%error, "failed to move the invalid theme registry aside");
                }
            }
            needs_persist = true;
            ThemeRegistry::default()
        }
    };

    // Step 2: Load every manifest; invalid themes are skipped with a warning.
    let mut manifests = disk::scan_manifests(&paths.themes_dir())?;

    // Step 3: Seed the built-in theme so the desktop always has a palette.
    if manifests.is_empty() {
        let manifest = ThemeManifest::default_theme()?;
        disk::write_manifest(&paths.manifest_file(&manifest.name), &manifest)?;
        info!(theme = %manifest.name, "seeded the built-in default theme");
        manifests.insert(manifest.name.clone(), manifest);
        needs_persist = true;
    }

    // Step 4: Reconcile the registry against the manifests on disk.
    let installed: Vec<ThemeId> = manifests.keys().cloned().collect();

    let dropped: Vec<&ThemeId> = loaded
        .installed
        .iter()
        .filter(|theme| !manifests.contains_key(*theme))
        .collect();
    if !dropped.is_empty() {
        warn!(
            ?dropped,
            "dropping registry entries whose manifests are missing"
        );
        needs_persist = true;
    }

    let adopted: Vec<&ThemeId> = manifests
        .keys()
        .filter(|theme| !loaded.installed.contains(theme))
        .collect();
    if !adopted.is_empty() {
        info!(?adopted, "adopting theme manifests found on disk");
        needs_persist = true;
    }

    let current_theme = loaded
        .current_theme
        .clone()
        .filter(|theme| manifests.contains_key(theme))
        .or_else(|| installed.first().cloned());
    if current_theme != loaded.current_theme {
        needs_persist = true;
    }

    let registry = ThemeRegistry {
        schema_version: REGISTRY_SCHEMA_VERSION,
        current_theme,
        color_scheme: loaded.color_scheme,
        installed,
    };

    if registry != loaded {
        needs_persist = true;
    }

    // Step 5: Persist only when something actually changed, so a normal start
    // does not rewrite the registry on every launch.
    if needs_persist {
        disk::write_registry(&paths.registry_file(), &registry)?;
        debug!("theme registry reconciled and persisted");
    }

    Ok(StoreState {
        registry,
        manifests,
    })
}

/// Returns the manifest of the active theme.
///
/// # Errors
/// Returns [`RdeError::NotFound`] when no theme is active or the active theme
/// is no longer installed.
fn active_manifest(state: &StoreState) -> RdeResult<&ThemeManifest> {
    let theme = state
        .registry
        .current_theme
        .as_ref()
        .ok_or_else(|| RdeError::NotFound("no active theme".to_string()))?;

    state
        .manifests
        .get(theme)
        .ok_or_else(|| not_installed(theme))
}

/// Builds the standard "theme is not installed" error.
fn not_installed(theme: &ThemeId) -> RdeError {
    RdeError::NotFound(format!("theme '{theme}' is not installed"))
}

#[cfg(test)]
mod tests {
    use std::{
        path::PathBuf,
        sync::atomic::{AtomicU64, Ordering},
    };

    use super::*;

    /// Isolated theme database directory removed when the test ends.
    struct TempRoot {
        path: PathBuf,
    }

    impl TempRoot {
        fn new(label: &str) -> Self {
            static COUNTER: AtomicU64 = AtomicU64::new(0);

            let unique = COUNTER.fetch_add(1, Ordering::Relaxed);
            let path = std::env::temp_dir().join(format!(
                "rde-theme-store-{}-{label}-{unique}",
                std::process::id()
            ));
            let _ = std::fs::remove_dir_all(&path);
            std::fs::create_dir_all(&path).expect("create temporary root");

            Self { path }
        }

        fn paths(&self) -> ThemePaths {
            ThemePaths::from_root(&self.path)
        }

        fn open(&self) -> ThemeStore {
            ThemeStore::open(self.paths()).expect("open theme store")
        }
    }

    impl Drop for TempRoot {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.path);
        }
    }

    fn id(value: &str) -> ThemeId {
        ThemeId::new(value).expect("valid theme id")
    }

    /// Backend that marks every palette with a sentinel primary color.
    struct FakeBackend;

    /// Primary color only [`FakeBackend`] produces.
    const FAKE_PRIMARY: u32 = 0xFF12_3456;

    impl ThemeBackend for FakeBackend {
        fn palette(&self, source_color: &str, color_scheme: ColorScheme) -> RdeResult<Palette> {
            let mut palette = MaterialBackend.palette(source_color, color_scheme)?;
            palette.primary = FAKE_PRIMARY;

            Ok(palette)
        }
    }

    #[test]
    fn open_seeds_the_default_theme() {
        let root = TempRoot::new("seed");
        let store = root.open();
        let default = id("default");

        assert_eq!(store.installed_themes(), vec![default.clone()]);
        assert_eq!(store.current_theme(), Some(default.clone()));
        assert_eq!(store.color_scheme(), ColorScheme::Light);
        assert_eq!(store.source_color().expect("source color"), "#6DD6DA");

        assert!(root.paths().registry_file().exists());
        assert!(root.paths().manifest_file(&default).exists());
        assert!(
            store.active_theme().is_ok(),
            "the seeded theme must resolve to a palette"
        );
    }

    #[test]
    fn injected_backend_supplies_palettes_to_the_store() {
        let root = TempRoot::new("backend-injection");
        let store = ThemeStore::open_with_backend(root.paths(), Box::new(FakeBackend))
            .expect("open theme store with a custom backend");

        let active = store.active_theme().expect("active theme");
        assert_eq!(active.color_scheme, ColorScheme::Light);
        assert_eq!(active.palette.primary, FAKE_PRIMARY);

        let dark = store
            .palette(&id("default"), ColorScheme::Dark)
            .expect("palette for another scheme");
        assert_eq!(dark.primary, FAKE_PRIMARY);
        assert_ne!(
            dark.surface, active.palette.surface,
            "the requested scheme must still reach the backend"
        );
    }

    #[test]
    fn default_store_uses_the_material_backend() {
        let root = TempRoot::new("default-backend");
        let store = root.open();

        let palette = store
            .palette(&id("default"), ColorScheme::Light)
            .expect("default palette");
        let expected = MaterialBackend
            .palette("#6DD6DA", ColorScheme::Light)
            .expect("material palette");

        assert_eq!(palette, expected);
    }

    #[test]
    fn create_theme_persists_manifest_and_registry() {
        let root = TempRoot::new("create");
        let store = root.open();
        let ocean = id("ocean");

        let manifest = store
            .create_theme(ocean.clone(), "#006A6A")
            .expect("create theme");

        assert_eq!(manifest.source_color, "#006A6A");
        assert_eq!(
            store.installed_themes(),
            vec![id("default"), ocean.clone()],
            "the installed list must stay sorted"
        );
        assert_eq!(
            store.current_theme(),
            Some(id("default")),
            "creating a theme must not activate it"
        );
        assert!(root.paths().manifest_file(&ocean).exists());

        // A fresh store must observe the persisted theme.
        let reopened = root.open();
        assert_eq!(reopened.installed_themes(), store.installed_themes());
        assert_eq!(
            reopened.manifest(&ocean).expect("reloaded manifest"),
            manifest
        );
    }

    #[test]
    fn create_theme_rejects_duplicates_and_invalid_colors() {
        let root = TempRoot::new("create-invalid");
        let store = root.open();

        let duplicate = store.create_theme(id("default"), "#123456");
        assert!(
            matches!(duplicate, Err(RdeError::AlreadyExists(_))),
            "installing an existing theme must fail with AlreadyExists"
        );

        let invalid_color = store.create_theme(id("ocean"), "#12345");
        assert!(
            matches!(invalid_color, Err(RdeError::InvalidValue(_))),
            "an invalid source color must be rejected"
        );
        assert!(
            !root.paths().theme_dir(&id("ocean")).exists(),
            "a rejected theme must not create a directory"
        );
    }

    #[test]
    fn set_theme_requires_an_installed_theme() {
        let root = TempRoot::new("set-theme");
        let store = root.open();
        let ocean = id("ocean");

        assert!(matches!(
            store.set_theme(&id("missing")),
            Err(RdeError::NotFound(_))
        ));

        store
            .create_theme(ocean.clone(), "#006A6A")
            .expect("create theme");
        store.set_theme(&ocean).expect("activate theme");

        assert_eq!(store.current_theme(), Some(ocean.clone()));
        assert_eq!(
            root.open().current_theme(),
            Some(ocean),
            "the active theme must survive a restart"
        );
    }

    #[test]
    fn palettes_follow_the_theme_and_scheme() {
        let root = TempRoot::new("palettes");
        let store = root.open();
        let ocean = id("ocean");
        store
            .create_theme(ocean.clone(), "#006A6A")
            .expect("create theme");

        let default_light = store
            .palette(&id("default"), ColorScheme::Light)
            .expect("default light");
        let ocean_light = store
            .palette(&ocean, ColorScheme::Light)
            .expect("ocean light");
        let ocean_dark = store
            .palette(&ocean, ColorScheme::Dark)
            .expect("ocean dark");

        assert_ne!(default_light.primary, ocean_light.primary);
        assert_ne!(ocean_light.surface, ocean_dark.surface);
    }

    #[test]
    fn set_source_color_updates_the_active_manifest() {
        let root = TempRoot::new("source-color");
        let store = root.open();

        let updated = store
            .set_source_color("#ff6200")
            .expect("update source color");
        assert_eq!(updated.source_color, "#FF6200");
        assert_eq!(store.source_color().expect("source color"), "#FF6200");

        let reopened = root.open();
        assert_eq!(
            reopened.source_color().expect("persisted source color"),
            "#FF6200"
        );

        assert!(store.set_source_color("nope").is_err());
    }

    #[test]
    fn delete_theme_removes_files_and_protects_the_active_theme() {
        let root = TempRoot::new("delete");
        let store = root.open();
        let ocean = id("ocean");

        assert!(
            matches!(
                store.delete_theme(&id("default")),
                Err(RdeError::InvalidValue(_))
            ),
            "the active theme must not be deletable"
        );

        store
            .create_theme(ocean.clone(), "#006A6A")
            .expect("create theme");
        store.delete_theme(&ocean).expect("delete theme");

        assert!(!root.paths().theme_dir(&ocean).exists());
        assert!(!store.installed_themes().contains(&ocean));
        assert!(
            !root.open().installed_themes().contains(&ocean),
            "the deletion must be persisted"
        );
    }

    #[test]
    fn color_scheme_changes_persist() {
        let root = TempRoot::new("scheme");
        let store = root.open();

        assert_eq!(
            store.toggle_color_scheme().expect("toggle scheme"),
            ColorScheme::Dark
        );
        assert_eq!(root.open().color_scheme(), ColorScheme::Dark);

        store
            .set_color_scheme(ColorScheme::Light)
            .expect("set scheme");
        assert_eq!(root.open().color_scheme(), ColorScheme::Light);
    }

    #[test]
    fn reload_rebuilds_a_corrupt_registry() {
        let root = TempRoot::new("rebuild");
        let store = root.open();
        let ocean = id("ocean");
        store
            .create_theme(ocean.clone(), "#006A6A")
            .expect("create theme");

        std::fs::write(root.paths().registry_file(), "not = [ valid").expect("corrupt registry");
        store.reload().expect("reload store");

        assert!(store.installed_themes().contains(&ocean));
        assert!(
            root.paths().root().join("themes.toml.invalid").exists(),
            "the corrupt registry must be kept for inspection"
        );
        assert!(
            root.paths().registry_file().exists(),
            "a rebuilt registry must be written"
        );
    }

    #[test]
    fn reload_adopts_external_manifests_and_drops_missing_themes() {
        let root = TempRoot::new("reconcile");
        let store = root.open();
        let ocean = id("ocean");
        store
            .create_theme(ocean.clone(), "#006A6A")
            .expect("create theme");

        // Step 1: Remove a theme directory behind the store's back.
        std::fs::remove_dir_all(root.paths().theme_dir(&ocean)).expect("remove theme directory");
        store.reload().expect("reload store");
        assert!(!store.installed_themes().contains(&ocean));

        // Step 2: Install a theme by writing its manifest directly.
        let external = id("external");
        let manifest =
            ThemeManifest::new(external.clone(), "#FF6200").expect("build external manifest");
        disk::write_manifest(&root.paths().manifest_file(&external), &manifest)
            .expect("write external manifest");

        store.reload().expect("reload store");
        assert!(
            store.installed_themes().contains(&external),
            "manifests found on disk must be adopted"
        );
    }
}
