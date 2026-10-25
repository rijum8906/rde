//! # Application Theme Service
//!
//! Orchestrates theme resolution, atomic publishing transactions, file watching,
//! and broadcast notifications.
//!
//! # Publishing Invariant
//! **Write the file first, then bump the generation, then emit the signal.**
//! Never emit before the file is durable on disk, ensuring subscribers that
//! immediately read `current.json` upon signal receipt observe the updated state.

use std::{
    path::{Path, PathBuf},
    sync::Arc,
    time::Duration,
};
use tokio::sync::{RwLock, broadcast};
use tracing::{debug, error, info, warn};

use crate::{
    backend::{Backend, compute_color_roles},
    domain::{
        identity::ThemeId,
        manifest::{ContrastLevel, ThemeManifest, ThemeMode},
        registry::ThemeRegistry,
        resolved::{
            AssetPaths, Color, Motion, ResolvedTheme, SUPPORTED_RESOLVED_SCHEMA_VERSION, Shape,
            Typography, VariantKind,
        },
        settings::{DynamicThemeUpdate, SeedSource, ThemeSettings},
    },
    fs::write_atomic,
    theme_store::{ThemeError, ThemeRepository},
};

/// Authoritative in-memory state of the published theme.
#[derive(Debug, Clone)]
pub struct PublishedState {
    /// Currently resolved theme payload.
    pub resolved: ResolvedTheme,

    /// Monotonically increasing publication generation counter.
    pub generation: u32,

    /// Identifier of the active theme (`None` for built-in dynamic).
    pub active: Option<ThemeId>,

    /// Active appearance mode (Light or Dark).
    pub mode: ThemeMode,
}

/// The central theme service coordinating the desktop appearance lifecycle.
pub struct ThemeService {
    repo: Arc<dyn ThemeRepository>,
    state: Arc<RwLock<PublishedState>>,
    backends: Vec<Arc<dyn Backend>>,
    cache_path: PathBuf,
    settings_path: PathBuf,
    themes_dir: PathBuf,

    /// Persisted user preferences, including the built-in dynamic theme inputs.
    settings: Arc<RwLock<ThemeSettings>>,

    theme_changed_tx: broadcast::Sender<ResolvedTheme>,
    reloaded_tx: broadcast::Sender<()>,
    theme_list_changed_tx: broadcast::Sender<Vec<ThemeId>>,
}

impl ThemeService {
    /// Performs the startup sequence and completes the initial publication transaction.
    ///
    /// # Execution Steps
    /// 1. Load user settings (recovering to default if missing or corrupt).
    /// 2. Load theme registry (rebuilding from disk if missing or corrupt).
    /// 3. Resolve active variant (falling back to built-in dynamic theme on error).
    /// 4. Atomically persist `current.json`.
    /// 5. Bump publication generation counter.
    /// 6. Render and atomically write all backend configuration files.
    /// 7. Apply backend environment variables to process environment.
    /// 8. Shell out to KDE color scheme application if running KDE.
    /// 9. Emit initial `ThemeChanged` notification.
    ///
    /// # Hard Invariant
    /// **Write the file first, then bump the generation, then emit the signal.**
    pub async fn startup(
        repo: Arc<dyn ThemeRepository>,
        backends: Vec<Arc<dyn Backend>>,
        cache_path: PathBuf,
        settings_path: PathBuf,
        themes_dir: PathBuf,
    ) -> Result<Self, ThemeError> {
        info!("Starting up ThemeService...");

        // Step 1: Load settings with recovery.
        let settings = repo.load_settings().await.unwrap_or_else(|err| {
            warn!(error = %err, "Failed to load settings during startup; using defaults");
            ThemeSettings::default()
        });

        // Step 2: Load registry with recovery.
        let registry = repo.load_registry().await.unwrap_or_else(|err| {
            warn!(error = %err, "Failed to load registry during startup; using empty fallback");
            ThemeRegistry::default()
        });

        // Step 3: Determine active theme and resolve initial payload.
        let active_theme = settings
            .active_theme
            .clone()
            .filter(|id| id.is_builtin() || registry.themes.contains_key(id));

        let target_theme_id = active_theme
            .clone()
            .unwrap_or_else(ThemeId::builtin_dynamic);

        let resolved = Self::resolve_with_fallback(
            repo.as_ref(),
            &target_theme_id,
            settings.mode,
            settings.contrast,
        )
        .await;

        // Step 4: Invariant Step A: Write current.json atomically first.
        let initial_generation = 1;
        if let Err(err) = Self::write_current_json(&cache_path, &resolved) {
            warn!(error = %err, "Failed to write initial current.json cache; in-memory state remains authoritative");
        }

        // Step 5: Invariant Step B: Increment generation & establish published state.
        let state = Arc::new(RwLock::new(PublishedState {
            resolved: resolved.clone(),
            generation: initial_generation,
            active: active_theme,
            mode: settings.mode,
        }));

        let settings = Arc::new(RwLock::new(settings));

        // Step 6: Render and write backend files atomically.
        Self::apply_backends(&backends, &resolved);

        // Step 7: Shell out to KDE if applicable.
        Self::maybe_apply_kde();

        // Broadcast channels (capacity 32)
        let (theme_changed_tx, _) = broadcast::channel(32);
        let (reloaded_tx, _) = broadcast::channel(32);
        let (theme_list_changed_tx, _) = broadcast::channel(32);

        // Step 8: Invariant Step C: Emit signal after files are durable.
        let _ = theme_changed_tx.send(resolved);

        info!("ThemeService startup transaction completed successfully");

        Ok(Self {
            repo,
            state,
            backends,
            cache_path,
            settings_path,
            themes_dir,
            settings,
            theme_changed_tx,
            reloaded_tx,
            theme_list_changed_tx,
        })
    }

    /// Resolves a theme variant with guaranteed fallback to the built-in dynamic theme.
    ///
    /// # Parameters
    /// - `repo`: repository providing manifests and variant payloads
    /// - `theme_id`: theme to resolve
    /// - `mode`: requested light/dark appearance
    /// - `contrast`: requested contrast level
    ///
    /// # Returns
    /// The resolved payload. Every failure path degrades gracefully: a broken
    /// manifest falls back to the built-in manifest, a broken payload falls back to
    /// the built-in dynamic theme, and a broken dynamic payload is computed in
    /// memory. Appearance never fails to resolve.
    async fn resolve_with_fallback(
        repo: &dyn ThemeRepository,
        theme_id: &ThemeId,
        mode: ThemeMode,
        contrast: ContrastLevel,
    ) -> ResolvedTheme {
        // Step 1: Load the manifest, falling back to the built-in dynamic manifest.
        let manifest = match repo.manifest(theme_id).await {
            Ok(manifest) => manifest,
            Err(err) => {
                warn!(theme = %theme_id, error = %err, "Failed to load manifest; falling back to the built-in dynamic theme");
                ThemeManifest::builtin_dynamic()
            }
        };

        // Step 2: Select the variant matching the requested mode and contrast.
        let (variant_id, _) = manifest.select_variant(mode, contrast);

        // Step 3: Resolve the variant payload.
        match repo.resolve_variant(&manifest.name, variant_id).await {
            Ok(resolved) => resolved,
            Err(err) => {
                warn!(theme = %manifest.name, variant = %variant_id, error = %err, "Failed to resolve variant; retrying with the built-in dynamic theme");
                let dynamic = ThemeManifest::builtin_dynamic();
                let (fallback_variant, _) = dynamic.select_variant(mode, contrast);

                match repo.resolve_variant(&dynamic.name, fallback_variant).await {
                    Ok(resolved) => resolved,
                    Err(err) => {
                        error!(error = %err, "Built-in dynamic theme resolution failed; using an in-memory palette");
                        Self::in_memory_fallback(mode, contrast)
                    }
                }
            }
        }
    }

    /// Builds the last-resort palette used when no payload can be resolved from disk.
    ///
    /// # Parameters
    /// - `mode`: requested light/dark appearance
    /// - `contrast`: requested contrast level
    ///
    /// # Returns
    /// A deterministic payload derived from [`Color::fallback`].
    fn in_memory_fallback(mode: ThemeMode, contrast: ContrastLevel) -> ResolvedTheme {
        let dynamic = ThemeManifest::builtin_dynamic();
        let (variant, _) = dynamic.select_variant(mode, contrast);

        ResolvedTheme {
            schema_version: SUPPORTED_RESOLVED_SCHEMA_VERSION,
            theme_id: ThemeId::builtin_dynamic(),
            variant: variant.clone(),
            kind: VariantKind::Dynamic,
            colors: compute_color_roles(&Color::fallback(), mode, contrast),
            typography: Typography::default(),
            shape: Shape::default(),
            motion: Motion::default(),
            assets: AssetPaths::default(),
        }
    }

    /// Internal helper writing `current.json` atomically.
    fn write_current_json(path: &Path, resolved: &ResolvedTheme) -> Result<(), ThemeError> {
        let bytes = serde_json::to_vec_pretty(resolved)
            .map_err(|e| ThemeError::Serialization(e.to_string()))?;
        write_atomic(path, &bytes).map_err(|source| ThemeError::Io {
            path: path.to_path_buf(),
            source,
        })
    }

    /// Internal helper rendering and writing backend outputs.
    fn apply_backends(backends: &[Arc<dyn Backend>], resolved: &ResolvedTheme) {
        for backend in backends {
            match backend.render(resolved) {
                Ok(output) => {
                    // Write files atomically
                    for (file_path, bytes) in output.files {
                        if let Err(err) = write_atomic(&file_path, &bytes) {
                            warn!(backend = %backend.name(), path = %file_path.display(), error = %err, "Failed to write backend file");
                        }
                    }
                    // Apply environment variables
                    for (key, value) in output.env {
                        unsafe {
                            std::env::set_var(&key, &value);
                        }
                    }
                }
                Err(err) => {
                    warn!(backend = %backend.name(), error = %err, "Backend render failure");
                }
            }
        }
    }

    /// Shells out to `plasma-apply-colorscheme` if the session is KDE Plasma.
    fn maybe_apply_kde() {
        let is_kde = std::env::var("XDG_CURRENT_DESKTOP")
            .map(|v| v.to_uppercase().contains("KDE"))
            .unwrap_or(false);

        if is_kde {
            debug!("Running on KDE; invoking plasma-apply-colorscheme");
            let _ = std::process::Command::new("plasma-apply-colorscheme")
                .arg("RdeM3")
                .status();
        }
    }

    /// Subscribes to `ThemeChanged` signals broadcast across the service.
    pub fn subscribe_theme_changed(&self) -> broadcast::Receiver<ResolvedTheme> {
        self.theme_changed_tx.subscribe()
    }

    /// Subscribes to `Reloaded` completion signals.
    pub fn subscribe_reloaded(&self) -> broadcast::Receiver<()> {
        self.reloaded_tx.subscribe()
    }

    /// Subscribes to `ThemeListChanged` registry changes.
    pub fn subscribe_theme_list_changed(&self) -> broadcast::Receiver<Vec<ThemeId>> {
        self.theme_list_changed_tx.subscribe()
    }

    /// Returns a snapshot of the current publication state.
    pub async fn current_state(&self) -> PublishedState {
        self.state.read().await.clone()
    }

    /// Returns a snapshot of the persisted user settings.
    pub async fn settings(&self) -> ThemeSettings {
        self.settings.read().await.clone()
    }

    /// Returns the underlying repository reference.
    pub fn repository(&self) -> Arc<dyn ThemeRepository> {
        self.repo.clone()
    }

    /// Single mutation entry point to switch the active theme.
    ///
    /// # Idempotency
    /// If the resolved theme matches the existing publication, no generation
    /// bump occurs and no signal is emitted.
    ///
    /// # Hard Invariant
    /// Write file first, then bump generation, then emit signal.
    pub async fn set_active(&self, id: ThemeId) -> Result<(), ThemeError> {
        info!(theme = %id, "Setting active theme");

        // Step 1: Validate theme existence (or reserved dynamic builtin).
        if !id.is_builtin() {
            let registry = self.repo.load_registry().await?;
            if !registry.themes.contains_key(&id) {
                return Err(ThemeError::NotFound(id));
            }
        }

        let current = self.state.read().await.clone();
        let settings = self.settings.read().await.clone();

        // Step 2: Resolve the target theme payload for the persisted appearance.
        let resolved =
            Self::resolve_with_fallback(self.repo.as_ref(), &id, current.mode, settings.contrast)
                .await;

        // Step 3: Idempotency check.
        if resolved == current.resolved && Some(&id) == current.active.as_ref() {
            debug!("Resolved theme is identical to published theme; skipping publication");
            return Ok(());
        }

        // Step 4: Perform publication transaction.
        self.publish_transaction(resolved, Some(id), current.mode)
            .await
    }

    /// Re-reads the active theme manifest and re-resolves the variant.
    ///
    /// Emits `ThemeChanged` only if the payload changed, and always emits `Reloaded`.
    pub async fn reload(&self) -> Result<(), ThemeError> {
        info!("Reloading theme service...");

        let current = self.state.read().await.clone();
        let settings = self.settings.read().await.clone();
        let target_theme_id = current
            .active
            .clone()
            .unwrap_or_else(ThemeId::builtin_dynamic);

        let resolved = Self::resolve_with_fallback(
            self.repo.as_ref(),
            &target_theme_id,
            current.mode,
            settings.contrast,
        )
        .await;

        if resolved != current.resolved {
            self.publish_transaction(resolved, current.active, current.mode)
                .await?;
        }

        // Always emit Reloaded signal
        let _ = self.reloaded_tx.send(());
        Ok(())
    }

    /// Resolves a theme without committing changes or emitting signals.
    ///
    /// Ideal for UI settings dialogs and pickers rendering live previews.
    pub async fn preview(
        &self,
        id: &ThemeId,
        mode: ThemeMode,
        contrast: ContrastLevel,
    ) -> Result<ResolvedTheme, ThemeError> {
        Ok(Self::resolve_with_fallback(self.repo.as_ref(), id, mode, contrast).await)
    }

    /// Updates the inputs of the built-in dynamic theme (`rde-dynamic`).
    ///
    /// # Parameters
    /// - `update`: partial set of dynamic inputs; `None` fields keep current values
    ///
    /// # Behavior
    /// Inputs are validated before anything is written, then `settings.toml` is
    /// persisted atomically and the in-memory snapshot is refreshed. When the
    /// dynamic theme is active it is re-resolved from the new seed and republished;
    /// a static active theme keeps its shipped payloads and picks the new inputs up
    /// on the next activation.
    ///
    /// # Errors
    /// Returns [`ThemeError::Settings`] when an input is rejected, or
    /// [`ThemeError::Io`] when the settings file cannot be written. A rejected
    /// update leaves both the file and the in-memory state untouched.
    pub async fn update_dynamic_theme(
        &self,
        update: DynamicThemeUpdate,
    ) -> Result<ThemeSettings, ThemeError> {
        info!("Updating built-in dynamic theme inputs");

        // Step 1: Apply and validate the update against the persisted settings.
        let mut next = self.settings.read().await.clone();
        update.apply(&mut next)?;

        // Step 2: Persist first; the settings file is the source of truth.
        self.repo.save_settings(&next).await?;

        // Step 3: Refresh the in-memory snapshot.
        *self.settings.write().await = next.clone();

        // Step 4: Republish the dynamic theme when it is the active theme.
        self.republish_if_dynamic().await?;

        Ok(next)
    }

    /// Notifies the service of an external wallpaper change to recompute dynamic themes.
    ///
    /// The path is persisted so wallpaper-derived colors survive a restart, and the
    /// dynamic theme is republished when it is active.
    ///
    /// # Errors
    /// Returns [`ThemeError::Settings`] when the path is not absolute, or
    /// [`ThemeError::Io`] when the settings file cannot be written.
    pub async fn notify_wallpaper_changed(&self, path: PathBuf) -> Result<(), ThemeError> {
        info!(path = %path.display(), "Desktop wallpaper changed; updating dynamic theme inputs");

        self.update_dynamic_theme(DynamicThemeUpdate {
            seed_source: Some(SeedSource::Wallpaper),
            fixed_seed: None,
            wallpaper: Some(path),
        })
        .await?;

        Ok(())
    }

    /// Re-resolves and republishes the built-in dynamic theme when it is active.
    ///
    /// # Errors
    /// Propagates publication failures from the cache write path.
    async fn republish_if_dynamic(&self) -> Result<(), ThemeError> {
        let current = self.state.read().await.clone();
        let is_dynamic = current
            .active
            .as_ref()
            .map(ThemeId::is_builtin)
            .unwrap_or(true);

        if !is_dynamic {
            debug!(
                "Active theme is not the built-in dynamic theme; new inputs apply on activation"
            );
            return Ok(());
        }

        let settings = self.settings.read().await.clone();
        let resolved = Self::resolve_with_fallback(
            self.repo.as_ref(),
            &ThemeId::builtin_dynamic(),
            current.mode,
            settings.contrast,
        )
        .await;

        if resolved != current.resolved {
            self.publish_transaction(resolved, current.active, current.mode)
                .await?;
        } else {
            debug!("Dynamic theme payload is unchanged; skipping publication");
        }

        Ok(())
    }

    /// Performs the atomic publication transaction honoring the hard ordering invariant:
    /// **Write file first, then bump generation, then emit signal.**
    async fn publish_transaction(
        &self,
        resolved: ResolvedTheme,
        active: Option<ThemeId>,
        mode: ThemeMode,
    ) -> Result<(), ThemeError> {
        // Step 1: Invariant Step A: Write current.json cache atomically first.
        if let Err(err) = Self::write_current_json(&self.cache_path, &resolved) {
            warn!(error = %err, "Failed to write current.json cache; proceeding with in-memory state");
        }

        // Step 2: Invariant Step B: Increment generation counter.
        let mut state_lock = self.state.write().await;
        let new_generation = state_lock.generation.saturating_add(1);
        *state_lock = PublishedState {
            resolved: resolved.clone(),
            generation: new_generation,
            active,
            mode,
        };
        drop(state_lock);

        // Step 3: Render and atomically write backend outputs.
        Self::apply_backends(&self.backends, &resolved);

        // Step 4: Shell out to KDE if applicable.
        Self::maybe_apply_kde();

        // Step 5: Invariant Step C: Emit ThemeChanged signal.
        let _ = self.theme_changed_tx.send(resolved);

        Ok(())
    }

    /// Spawns a background task watching configuration files and themes directories.
    pub fn start_watcher(self: &Arc<Self>) {
        let service = self.clone();
        tokio::spawn(async move {
            service.watch_loop().await;
        });
    }

    /// Internal debounced watch loop using `notify`.
    async fn watch_loop(&self) {
        use notify::{Event, RecursiveMode, Watcher};

        let (tx, mut rx) = tokio::sync::mpsc::channel(64);

        let mut watcher =
            match notify::recommended_watcher(move |res: Result<Event, notify::Error>| {
                if let Ok(event) = res {
                    let _ = tx.blocking_send(event);
                }
            }) {
                Ok(w) => w,
                Err(err) => {
                    warn!(error = %err, "Failed to initialize filesystem watcher");
                    return;
                }
            };

        if self.settings_path.exists() {
            let _ = watcher.watch(&self.settings_path, RecursiveMode::NonRecursive);
        }
        if self.themes_dir.exists() {
            let _ = watcher.watch(&self.themes_dir, RecursiveMode::Recursive);
        }

        // Debounce loop: 150ms window
        while rx.recv().await.is_some() {
            // Sleep for debounce interval
            tokio::time::sleep(Duration::from_millis(150)).await;

            // Drain any pending events that arrived during sleep
            while rx.try_recv().is_ok() {}

            debug!("Filesystem change detected after debounce; reloading theme service");
            let _ = self.reload().await;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{
        identity::VariantId,
        manifest::{ContrastLevel, RelativePath, ThemeMode, VariantDescriptor},
        registry::{ThemeEntry, ThemeLocation, ThemeRegistry, ThemeSource},
        resolved::{AssetPaths, Color, Motion, Shape, Typography, VariantKind},
    };
    use async_trait::async_trait;
    use std::collections::BTreeMap;

    struct FakeRepo {
        manifests: std::sync::Mutex<BTreeMap<ThemeId, ThemeManifest>>,
        registry: std::sync::Mutex<ThemeRegistry>,
        resolved_map: std::sync::Mutex<BTreeMap<(ThemeId, VariantId), ResolvedTheme>>,
        settings: std::sync::Mutex<ThemeSettings>,
        rebuild_called: std::sync::atomic::AtomicBool,
    }

    impl FakeRepo {
        fn new() -> Self {
            Self {
                manifests: std::sync::Mutex::new(BTreeMap::new()),
                registry: std::sync::Mutex::new(ThemeRegistry::default()),
                resolved_map: std::sync::Mutex::new(BTreeMap::new()),
                settings: std::sync::Mutex::new(ThemeSettings::default()),
                rebuild_called: std::sync::atomic::AtomicBool::new(false),
            }
        }
    }

    #[async_trait]
    impl ThemeRepository for FakeRepo {
        async fn manifest(&self, id: &ThemeId) -> Result<ThemeManifest, ThemeError> {
            if id.is_builtin() {
                return Ok(ThemeManifest::builtin_dynamic());
            }
            self.manifests
                .lock()
                .unwrap()
                .get(id)
                .cloned()
                .ok_or_else(|| ThemeError::NotFound(id.clone()))
        }

        async fn entry(&self, id: &ThemeId) -> Result<Option<ThemeEntry>, ThemeError> {
            Ok(self.registry.lock().unwrap().themes.get(id).cloned())
        }

        async fn list(&self) -> Result<Vec<ThemeId>, ThemeError> {
            Ok(self
                .registry
                .lock()
                .unwrap()
                .themes
                .keys()
                .cloned()
                .collect())
        }

        async fn load_registry(&self) -> Result<ThemeRegistry, ThemeError> {
            Ok(self.registry.lock().unwrap().clone())
        }

        async fn save_registry(&self, reg: &ThemeRegistry) -> Result<(), ThemeError> {
            *self.registry.lock().unwrap() = reg.clone();
            Ok(())
        }

        async fn load_settings(&self) -> Result<ThemeSettings, ThemeError> {
            Ok(self.settings.lock().unwrap().clone())
        }

        async fn save_settings(&self, settings: &ThemeSettings) -> Result<(), ThemeError> {
            *self.settings.lock().unwrap() = settings.clone();
            Ok(())
        }

        async fn resolve_variant(
            &self,
            id: &ThemeId,
            variant: &VariantId,
        ) -> Result<ResolvedTheme, ThemeError> {
            if let Some(res) = self
                .resolved_map
                .lock()
                .unwrap()
                .get(&(id.clone(), variant.clone()))
            {
                return Ok(res.clone());
            }

            // Return a dynamic fallback derived from the repository's current settings,
            // mirroring the disk repository's seed handling.
            let settings = self.settings.lock().unwrap().clone();
            let seed = settings
                .dynamic
                .fixed_seed
                .as_deref()
                .and_then(|seed| Color::new(seed).ok())
                .unwrap_or_else(Color::fallback);
            let colors = crate::backend::material::compute_color_roles(
                &seed,
                ThemeMode::Dark,
                ContrastLevel::Normal,
            );
            Ok(ResolvedTheme {
                schema_version: 1,
                theme_id: id.clone(),
                variant: variant.clone(),
                kind: VariantKind::Dynamic,
                colors,
                typography: Typography::default(),
                shape: Shape::default(),
                motion: Motion::default(),
                assets: AssetPaths::default(),
            })
        }

        async fn rebuild_registry(&self) -> Result<ThemeRegistry, ThemeError> {
            self.rebuild_called
                .store(true, std::sync::atomic::Ordering::SeqCst);
            let mut reg = self.registry.lock().unwrap();
            reg.schema_version = 1;
            Ok(reg.clone())
        }
    }

    fn sample_resolved(theme_id: &ThemeId, variant_id: &VariantId) -> ResolvedTheme {
        let colors = crate::backend::material::compute_color_roles(
            &Color::new("#123456").unwrap(),
            ThemeMode::Dark,
            ContrastLevel::Normal,
        );
        ResolvedTheme {
            schema_version: 1,
            theme_id: theme_id.clone(),
            variant: variant_id.clone(),
            kind: VariantKind::Static,
            colors,
            typography: Typography::default(),
            shape: Shape::default(),
            motion: Motion::default(),
            assets: AssetPaths::default(),
        }
    }

    #[tokio::test]
    async fn test_set_active_idempotency() {
        let temp = tempfile::tempdir().unwrap();
        let cache_file = temp.path().join("current.json");
        let settings_file = temp.path().join("settings.toml");
        let themes_dir = temp.path().join("themes");

        let repo = Arc::new(FakeRepo::new());
        let theme_a = ThemeId::new("theme-a").unwrap();
        let dark_var = VariantId::new("dark").unwrap();

        // Setup theme-a in repo
        repo.registry.lock().unwrap().themes.insert(
            theme_a.clone(),
            ThemeEntry {
                location: ThemeLocation::User,
                source: ThemeSource::User,
                installed_at: 0,
            },
        );
        let mut variants = BTreeMap::new();
        variants.insert(
            dark_var.clone(),
            VariantDescriptor {
                mode: ThemeMode::Dark,
                contrast: ContrastLevel::Normal,
                display_name: None.into(),
                file_path: RelativePath::new("dark.json").unwrap(),
                preview: None.into(),
            },
        );
        let manifest = ThemeManifest {
            schema_version: 1,
            name: theme_a.clone(),
            display_name: "Theme A".into(),
            description: "A".into(),
            author: None.into(),
            license: None.into(),
            version: "1.0.0".into(),
            variants,
            default_variant: dark_var.clone(),
        };
        repo.manifests
            .lock()
            .unwrap()
            .insert(theme_a.clone(), manifest);
        let res_a = sample_resolved(&theme_a, &dark_var);
        repo.resolved_map
            .lock()
            .unwrap()
            .insert((theme_a.clone(), dark_var.clone()), res_a.clone());

        let service = ThemeService::startup(
            repo.clone(),
            vec![],
            cache_file.clone(),
            settings_file,
            themes_dir,
        )
        .await
        .unwrap();

        // Set active to theme_a
        service.set_active(theme_a.clone()).await.unwrap();
        let state_after_first = service.current_state().await;
        let gen_first = state_after_first.generation;

        let mut sub = service.subscribe_theme_changed();

        // Calling set_active again with the same theme must be idempotent!
        service.set_active(theme_a.clone()).await.unwrap();
        let state_after_second = service.current_state().await;
        assert_eq!(state_after_second.generation, gen_first);

        // No signal emitted on idempotent call
        assert!(sub.try_recv().is_err());
    }

    #[tokio::test]
    async fn test_update_dynamic_theme_persists_and_republishes() {
        let temp = tempfile::tempdir().unwrap();
        let cache_file = temp.path().join("current.json");
        let settings_file = temp.path().join("settings.toml");
        let themes_dir = temp.path().join("themes");

        let repo = Arc::new(FakeRepo::new());
        let service = Arc::new(
            ThemeService::startup(repo.clone(), vec![], cache_file, settings_file, themes_dir)
                .await
                .unwrap(),
        );

        // The built-in dynamic theme is active right after startup.
        let generation_before = service.current_state().await.generation;
        let mut sub = service.subscribe_theme_changed();

        // Step 1: Update the seed inputs and expect a republish.
        let settings = service
            .update_dynamic_theme(DynamicThemeUpdate {
                seed_source: Some(SeedSource::Fixed),
                fixed_seed: Some("#006a6a".to_string()),
                wallpaper: None,
            })
            .await
            .unwrap();
        assert_eq!(settings.dynamic.seed_source, SeedSource::Fixed);

        // The inputs are persisted through the repository, not only held in memory.
        assert_eq!(
            repo.settings.lock().unwrap().dynamic.fixed_seed.as_deref(),
            Some("#006a6a")
        );

        let state_after = service.current_state().await;
        assert_eq!(state_after.generation, generation_before + 1);
        let received = sub.try_recv().expect("republished dynamic theme");
        assert_eq!(received, state_after.resolved);
        assert_eq!(received.kind, VariantKind::Dynamic);
        assert_eq!(
            received.colors,
            crate::backend::material::compute_color_roles(
                &Color::new("#006a6a").unwrap(),
                ThemeMode::Dark,
                ContrastLevel::Normal,
            )
        );

        // Step 2: A rejected update must not touch the persisted inputs.
        let rejected = service
            .update_dynamic_theme(DynamicThemeUpdate {
                seed_source: Some(SeedSource::Fixed),
                fixed_seed: Some("teal".to_string()),
                wallpaper: None,
            })
            .await;
        assert!(matches!(rejected, Err(ThemeError::Settings(_))));
        assert_eq!(
            service.settings().await.dynamic.fixed_seed.as_deref(),
            Some("#006a6a")
        );
    }

    #[tokio::test]
    async fn test_publish_ordering_file_durable_before_signal() {
        let temp = tempfile::tempdir().unwrap();
        let cache_file = temp.path().join("current.json");
        let settings_file = temp.path().join("settings.toml");
        let themes_dir = temp.path().join("themes");

        let repo = Arc::new(FakeRepo::new());
        let theme_b = ThemeId::new("theme-b").unwrap();
        let dark_var = VariantId::new("dark").unwrap();

        repo.registry
            .lock()
            .unwrap()
            .themes
            .insert(theme_b.clone(), ThemeEntry::default());
        let mut variants = BTreeMap::new();
        variants.insert(
            dark_var.clone(),
            VariantDescriptor {
                mode: ThemeMode::Dark,
                contrast: ContrastLevel::Normal,
                display_name: None.into(),
                file_path: RelativePath::new("dark.json").unwrap(),
                preview: None.into(),
            },
        );
        let manifest = ThemeManifest {
            schema_version: 1,
            name: theme_b.clone(),
            display_name: "Theme B".into(),
            description: "B".into(),
            author: None.into(),
            license: None.into(),
            version: "1.0.0".into(),
            variants,
            default_variant: dark_var.clone(),
        };
        repo.manifests
            .lock()
            .unwrap()
            .insert(theme_b.clone(), manifest);
        let res_b = sample_resolved(&theme_b, &dark_var);
        repo.resolved_map
            .lock()
            .unwrap()
            .insert((theme_b.clone(), dark_var.clone()), res_b.clone());

        let service = Arc::new(
            ThemeService::startup(
                repo.clone(),
                vec![],
                cache_file.clone(),
                settings_file,
                themes_dir,
            )
            .await
            .unwrap(),
        );

        let mut sub = service.subscribe_theme_changed();
        let target_cache = cache_file.clone();

        // Spawn a task that verifies file is already durable the moment signal arrives
        let verify_task = tokio::spawn(async move {
            let received = sub.recv().await.unwrap();
            // Invariant verification: file exists and matches payload!
            assert!(target_cache.exists());
            let file_content = std::fs::read_to_string(&target_cache).unwrap();
            let parsed_file: ResolvedTheme = serde_json::from_str(&file_content).unwrap();
            assert_eq!(parsed_file, received);
        });

        service.set_active(theme_b).await.unwrap();
        verify_task.await.unwrap();
    }
}
