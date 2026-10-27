//! # Application Theme Service
//!
//! Orchestrates theme resolution, atomic publishing transactions, file watching,
//! and broadcast notifications.
//!
//! # Publishing Invariant
//! **Write the file first, then bump the generation, then emit the signal.**
//! Never emit before the file is durable on disk, ensuring subscribers that
//! read `default_theme.json` upon signal receipt observe the updated state.

use std::{
    path::{Path, PathBuf},
    sync::{
        Arc,
        atomic::{AtomicU32, Ordering},
    },
    time::Duration,
};
use tokio::sync::{Mutex, RwLock, broadcast};
use tracing::{debug, error, info, warn};

use crate::{
    backend::{
        AdapterRegistry, compute_color_roles, detect::SessionEnv, kde::KDE_ADAPTER_NAME,
        resolvers::ResolverRegistry, unique_theme_name,
    },
    domain::{
        identity::{ThemeId, VariantId},
        manifest::{ContrastLevel, ThemeManifest, ThemeMode},
        registry::ThemeRegistry,
        resolved::{
            ColorSeeds, Motion, ResolvedTheme, SUPPORTED_RESOLVED_SCHEMA_VERSION, Shape,
            Typography, VariantKind,
        },
        settings::{DynamicThemeUpdate, ThemeSettings},
    },
    fs::write_atomic,
    paths::ThemePaths,
    theme_store::{DiskThemeRepository, ThemeError, ThemeRepository},
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
    /// Persistence backend for themes, settings, and the installed-theme registry.
    pub repo: Arc<dyn ThemeRepository>,

    /// Installed-theme registry snapshot, refreshed by [`ThemeService::reload`].
    pub theme_registry: RwLock<ThemeRegistry>,

    /// Persisted user preferences, including the built-in dynamic theme inputs.
    pub theme_settings: RwLock<ThemeSettings>,

    /// Manifest of the published theme, refreshed on every switch.
    pub theme_manifest: RwLock<ThemeManifest>,

    /// Currently published palette.
    pub resolved_theme: RwLock<ResolvedTheme>,

    /// Toolkit adapters rendered on every publication.
    ///
    /// Guarded by a lock because a publication hands every adapter the unique
    /// theme name of its generation before rendering it.
    pub adapter_registry: RwLock<AdapterRegistry>,

    /// Palette resolvers known to this build.
    pub resolver_registry: ResolverRegistry,

    /// Desktop session detected once at startup.
    pub session_env: SessionEnv,

    cache_path: PathBuf,
    settings_path: PathBuf,
    themes_dir: PathBuf,
    generation: AtomicU32,

    /// Serializes publication transactions.
    publish_guard: Mutex<()>,

    theme_changed_tx: broadcast::Sender<ResolvedTheme>,
    reloaded_tx: broadcast::Sender<()>,
    theme_list_changed_tx: broadcast::Sender<Vec<ThemeId>>,
}

impl ThemeService {
    /// Performs the startup sequence and completes the initial publication transaction.
    ///
    /// # Parameters
    /// - `repo`: persistence backend for themes, settings, and the registry
    /// - `adapter_registry`: toolkit adapters rendered on every publication
    /// - `cache_path`: published palette cache read by consumers
    /// - `settings_path`: user settings file watched for changes
    /// - `themes_dir`: theme root watched for installs and edits
    ///
    /// # Execution Steps
    /// 1. Load user settings (recovering to default if missing or corrupt).
    /// 2. Load theme registry (rebuilding from disk if missing or corrupt).
    /// 3. Resolve active variant (falling back to built-in dynamic theme on error).
    /// 4. Atomically persist the published theme cache.
    /// 5. Establish the in-memory publication state.
    /// 6. Render every adapter and atomically write its configuration files.
    /// 7. Shell out to KDE color scheme application if running KDE.
    /// 8. Emit initial `ThemeChanged` notification.
    ///
    /// # Errors
    /// Returns [`ThemeError`] for repository failures that prevent the initial
    /// publication; missing or corrupt settings, registries, and manifests
    /// degrade to defaults instead.
    ///
    /// # Hard Invariant
    /// **Write the file first, then bump the generation, then emit the signal.**
    pub async fn startup(
        repo: Arc<dyn ThemeRepository>,
        adapter_registry: AdapterRegistry,
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

        // Step 3b: Snapshot the manifest so `theme_manifest` can answer before
        // the next switch without touching the repository again.
        let manifest = match repo.manifest(&target_theme_id).await {
            Ok(manifest) => manifest,
            Err(err) => {
                warn!(theme = %target_theme_id, error = %err, "Failed to load manifest during startup; using the built-in manifest");
                ThemeManifest::builtin_dynamic()
            }
        };

        // Step 4: Invariant Step A: Write the published theme cache atomically first.
        if let Err(err) = Self::write_current_json(&cache_path, &resolved) {
            warn!(error = %err, "Failed to write initial published theme cache; in-memory state remains authoritative");
        }

        // Step 5: Establish the in-memory publication state. The startup
        // transaction is generation 1, so it names every artifact `...-v1`.
        let generation = 1;
        let mut theme_settings = settings;
        theme_settings.active_theme = active_theme;

        // Step 6: Render and atomically write every adapter output, deleting the
        // artifacts a previous run of the daemon left behind under the same name.
        let adapter_registry = RwLock::new(adapter_registry);
        let applied = Self::apply_adapters(&adapter_registry, &resolved, generation).await;

        // Step 7: Detect the session environment once for the whole service.
        let session_env = SessionEnv::detect();

        // Step 8: Shell out to KDE if the Qt adapter installed the scheme.
        if applied.contains(&KDE_ADAPTER_NAME) {
            let scheme_name = unique_theme_name(&resolved.theme_id, &resolved.variant, generation);
            Self::maybe_apply_kde(&session_env, &scheme_name);
        }

        // Broadcast channels (capacity 32)
        let (theme_changed_tx, _) = broadcast::channel(32);
        let (reloaded_tx, _) = broadcast::channel(32);
        let (theme_list_changed_tx, _) = broadcast::channel(32);

        // Step 9: Invariant Step C: Emit signal after files are durable.
        let _ = theme_changed_tx.send(resolved.clone());

        info!("ThemeService startup transaction completed successfully");

        Ok(Self {
            repo,
            theme_registry: RwLock::new(registry),
            theme_settings: RwLock::new(theme_settings),
            theme_manifest: RwLock::new(manifest),
            resolved_theme: RwLock::new(resolved),
            adapter_registry,
            resolver_registry: ResolverRegistry::build(),
            session_env,
            cache_path,
            settings_path,
            themes_dir,
            generation: AtomicU32::new(generation),
            publish_guard: Mutex::new(()),
            theme_changed_tx,
            reloaded_tx,
            theme_list_changed_tx,
        })
    }

    /// Constructs the service from the standard XDG locations.
    ///
    /// # Errors
    /// Returns [`ThemeError`] when the initial publication fails; the theme,
    /// config, and cache directories are resolved or created by the repository.
    pub async fn new() -> Result<Self, ThemeError> {
        let paths = ThemePaths::resolve();

        // Step 1: Build the disk repository from the standard XDG roots.
        let repo = DiskThemeRepository::new(
            paths.data_themes_dir().to_path_buf(),
            paths.config_themes_dir().to_path_buf(),
            paths.cache_theme_dir().to_path_buf(),
        )
        .with_system_themes(paths.system_themes_dir().to_path_buf());

        // Step 2: Delegate to the explicit startup sequence with the adapters
        // discovered by this build.
        Self::startup(
            Arc::new(repo),
            AdapterRegistry::build(),
            paths.published_theme_file(),
            paths.settings_file(),
            paths.data_themes_dir().to_path_buf(),
        )
        .await
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
            colors: compute_color_roles(&ColorSeeds::fallback(), mode, contrast),
            typography: Typography::default(),
            shape: Shape::default(),
            motion: Motion::default(),
        }
    }

    /// Internal helper writing the published theme cache atomically.
    fn write_current_json(path: &Path, resolved: &ResolvedTheme) -> Result<(), ThemeError> {
        let bytes = serde_json::to_vec_pretty(resolved)
            .map_err(|e| ThemeError::Serialization(e.to_string()))?;
        write_atomic(path, &bytes)?;

        Ok(())
    }

    /// Renders every registered adapter and writes its files atomically.
    ///
    /// # Parameters
    /// - `adapter_registry`: adapters to render, keyed by identifier
    /// - `resolved`: palette handed to every adapter
    /// - `generation`: publication generation the rendered artifacts belong to
    ///
    /// # Returns
    /// The name of every adapter that rendered successfully, so the caller can
    /// decide which desktop-specific notification to run afterwards.
    ///
    /// # Error Handling
    /// Failures are logged per adapter: one unavailable toolkit must never stop
    /// the remaining surfaces from being themed.
    async fn apply_adapters(
        adapter_registry: &RwLock<AdapterRegistry>,
        resolved: &ResolvedTheme,
        generation: u32,
    ) -> Vec<&'static str> {
        // Step 1: Name every artifact after the theme, the variant, and the
        // generation, so a regenerated palette never collides with the artifact
        // the desktop is currently reading.
        let theme_name = unique_theme_name(&resolved.theme_id, &resolved.variant, generation);

        let mut registry = adapter_registry.write().await;
        let mut applied = Vec::new();

        for adapter in registry.adapters.values_mut() {
            adapter.set_unique_theme_name(theme_name.clone());

            match adapter.render(resolved) {
                Ok(output) => {
                    // Step 2: Write every rendered file atomically so consumers
                    // never observe a partially themed file.
                    for (file_path, bytes) in output.files {
                        if let Err(err) = write_atomic(&file_path, &bytes) {
                            warn!(adapter = %adapter.name(), path = %file_path.display(), error = %err, "Failed to write adapter file");
                        }
                    }

                    // Step 3: Delete the artifacts of earlier generations, now
                    // that their replacements are durable on disk.
                    for superseded in output.removals {
                        Self::remove_superseded(&superseded);
                    }

                    // Step 4: Export the environment the adapter needs in child
                    // processes (for example `QT_QPA_PLATFORMTHEME`).
                    for (key, value) in output.env {
                        unsafe {
                            std::env::set_var(&key, &value);
                        }
                    }

                    applied.push(adapter.name());
                }
                Err(err) => {
                    warn!(adapter = %adapter.name(), error = %err, "Adapter render failure");
                }
            }
        }

        applied
    }

    /// Deletes an artifact that the current generation supersedes.
    ///
    /// # Parameters
    /// - `path`: file the adapter reported as superseded
    ///
    /// # Behavior
    /// A file that is already gone counts as success: a previous publication or
    /// the user may have removed it. Any other failure is logged and ignored,
    /// because a stale file must never abort a publication.
    fn remove_superseded(path: &Path) {
        match std::fs::remove_file(path) {
            Ok(()) => debug!(path = %path.display(), "Deleted superseded adapter output"),
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => {}
            Err(err) => {
                warn!(path = %path.display(), error = %err, "Failed to delete superseded adapter output")
            }
        }
    }

    /// Hands the freshly installed color scheme to KDE Plasma.
    ///
    /// # Parameters
    /// - `session_env`: session detected at startup
    /// - `scheme_name`: unique name of the scheme the Qt adapter installed
    ///
    /// # Behavior
    /// Plasma keeps the scheme it loaded, so a regeneration stays invisible until
    /// `plasma-apply-colorscheme` points it at the new name. The command is
    /// best-effort: a missing binary or a failed apply is logged, never fatal,
    /// because the files are already on disk for the next launch.
    fn maybe_apply_kde(session_env: &SessionEnv, scheme_name: &str) {
        if !session_env.is_kde() {
            debug!(
                scheme = scheme_name,
                "Not a KDE session; skipping plasma-apply-colorscheme"
            );
            return;
        }

        debug!(
            scheme = scheme_name,
            "Running on KDE; invoking plasma-apply-colorscheme"
        );

        match std::process::Command::new("plasma-apply-colorscheme")
            .arg(scheme_name)
            .status()
        {
            Ok(status) if status.success() => {
                info!(scheme = scheme_name, "Applied KDE color scheme")
            }
            Ok(status) => {
                warn!(scheme = scheme_name, status = ?status, "plasma-apply-colorscheme failed")
            }
            Err(err) => {
                warn!(scheme = scheme_name, error = %err, "Failed to run plasma-apply-colorscheme")
            }
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
        let settings = self.theme_settings.read().await;
        PublishedState {
            resolved: self.resolved_theme.read().await.clone(),
            generation: self.generation.load(Ordering::SeqCst),
            active: settings.active_theme.clone(),
            mode: settings.mode,
        }
    }

    /// Returns a snapshot of the persisted user settings.
    pub async fn settings(&self) -> ThemeSettings {
        self.theme_settings.read().await.clone()
    }

    /// Returns the underlying repository reference.
    pub fn repository(&self) -> Arc<dyn ThemeRepository> {
        self.repo.clone()
    }

    /// Returns the currently published [`ResolvedTheme`].
    pub async fn resolved_theme(&self) -> ResolvedTheme {
        self.resolved_theme.read().await.clone()
    }

    /// Returns the manifest describing the published theme.
    ///
    /// The snapshot is refreshed by [`Self::set_active`], [`Self::activate_theme`],
    /// and [`Self::reload`], so it never needs a repository round-trip.
    pub async fn theme_manifest(&self) -> ThemeManifest {
        self.theme_manifest.read().await.clone()
    }

    /// Returns the persisted appearance mode.
    pub async fn theme_mode(&self) -> ThemeMode {
        self.theme_settings.read().await.mode
    }

    /// Returns a snapshot of the installed-theme registry.
    pub async fn theme_registry(&self) -> ThemeRegistry {
        self.theme_registry.read().await.clone()
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

        let current = self.current_state().await;
        let mut settings = self.theme_settings.read().await.clone();

        // Step 2: Resolve the target theme payload for the persisted appearance.
        let resolved =
            Self::resolve_with_fallback(self.repo.as_ref(), &id, current.mode, settings.contrast)
                .await;

        // Step 2b: Load the manifest so the snapshot describes the new theme.
        let manifest = match self.repo.manifest(&id).await {
            Ok(manifest) => manifest,
            Err(err) => {
                warn!(theme = %id, error = %err, "Failed to load manifest while switching themes; using the built-in manifest");
                ThemeManifest::builtin_dynamic()
            }
        };

        // Step 3: Idempotency check.
        if resolved == current.resolved && Some(&id) == current.active.as_ref() {
            debug!("Resolved theme is identical to published theme; skipping publication");
            return Ok(());
        }

        // Step 4: Persist the choice before publishing, so a restart restores
        // the same theme into the published cache.
        settings.active_theme = Some(id.clone());
        self.repo.save_settings(&settings).await?;
        *self.theme_settings.write().await = settings;

        // Step 4b: Refresh the manifest snapshot before publishing.
        *self.theme_manifest.write().await = manifest;

        // Step 5: Perform publication transaction.
        self.publish_transaction(resolved).await
    }

    /// Switches to an exact variant of a theme, bypassing mode/contrast selection.
    ///
    /// # Parameters
    /// - `theme_id`: theme to activate; the built-in dynamic theme is allowed
    /// - `variant_id`: variant file to resolve inside that theme
    ///
    /// # Idempotency
    /// When the requested variant is already published for the same theme and
    /// appearance mode, nothing is written and no signal is emitted.
    ///
    /// # Hard Invariant
    /// The preference is persisted before the resolved payload is written, the
    /// generation is bumped, and `ThemeChanged` is emitted.
    ///
    /// # Errors
    /// Returns [`ThemeError::NotFound`] when the theme or variant does not exist,
    /// and propagates persistence or resolution failures unchanged.
    pub async fn activate_theme(
        &self,
        theme_id: ThemeId,
        variant_id: VariantId,
    ) -> Result<(), ThemeError> {
        info!(theme = %theme_id, variant = %variant_id, "Activating theme variant");

        // Step 1: Load the manifest; the repository supplies the built-in manifest.
        let manifest = self.repo.manifest(&theme_id).await?;

        // Step 2: Resolve the exact requested variant.
        let resolved = self.repo.resolve_variant(&theme_id, &variant_id).await?;

        let current = self.current_state().await;
        let mut settings = self.theme_settings.read().await.clone();

        // Step 3: Derive the appearance mode and contrast from the variant
        // descriptor, keeping the published values when it is unknown.
        if let Some(descriptor) = manifest.variants.get(&variant_id) {
            settings.mode = descriptor.mode;
            settings.contrast = descriptor.contrast;
        }
        let mode = settings.mode;

        // Step 4: Idempotency check.
        if resolved == current.resolved
            && current.active.as_ref() == Some(&theme_id)
            && current.mode == mode
        {
            debug!("Requested variant is already published; skipping publication");
            return Ok(());
        }

        // Step 5: Persist the selection before publishing, so a restart restores
        // the same theme and variant.
        settings.active_theme = Some(theme_id.clone());
        self.repo.save_settings(&settings).await?;
        *self.theme_settings.write().await = settings;

        // Step 6: Refresh the manifest snapshot and publish.
        *self.theme_manifest.write().await = manifest;

        self.publish_transaction(resolved).await
    }

    /// Switches the desktop appearance mode and republishes the active theme.
    ///
    /// # Idempotency
    /// Selecting the already published mode leaves the generation and signals untouched.
    ///
    /// # Hard Invariant
    /// The preference is persisted before the resolved payload is written, the
    /// generation is bumped, and `ThemeChanged` is emitted.
    pub async fn set_mode(&self, mode: ThemeMode) -> Result<(), ThemeError> {
        info!(mode = ?mode, "Setting appearance mode");

        // Step 1: Read the persisted settings and stop early when nothing changes.
        let mut next = self.theme_settings.read().await.clone();
        let current = self.current_state().await;
        if next.mode == mode && current.mode == mode {
            debug!("Appearance mode is unchanged; skipping publication");
            return Ok(());
        }

        // Step 2: Persist the new preference before touching the published state.
        next.mode = mode;
        self.repo.save_settings(&next).await?;
        *self.theme_settings.write().await = next.clone();

        // Step 3: Resolve the active theme's variant for the new mode.
        let target_theme_id = current
            .active
            .clone()
            .unwrap_or_else(ThemeId::builtin_dynamic);
        let resolved =
            Self::resolve_with_fallback(self.repo.as_ref(), &target_theme_id, mode, next.contrast)
                .await;

        // Step 4: Publish; the generation bump notifies every themed application.
        self.publish_transaction(resolved).await
    }

    /// Re-reads the installed-theme registry, the active manifest, and the variant.
    ///
    /// Emits `ThemeChanged` only if the payload changed, and always emits `Reloaded`.
    pub async fn reload(&self) -> Result<(), ThemeError> {
        info!("Reloading theme service...");

        let current = self.current_state().await;
        let settings = self.theme_settings.read().await.clone();
        let target_theme_id = current
            .active
            .clone()
            .unwrap_or_else(ThemeId::builtin_dynamic);

        // Step 1: Refresh the registry snapshot so new or removed themes are visible.
        match self.repo.load_registry().await {
            Ok(registry) => *self.theme_registry.write().await = registry,
            Err(err) => warn!(error = %err, "Failed to reload the theme registry snapshot"),
        }

        // Step 2: Refresh the manifest snapshot of the active theme.
        match self.repo.manifest(&target_theme_id).await {
            Ok(manifest) => *self.theme_manifest.write().await = manifest,
            Err(err) => {
                warn!(theme = %target_theme_id, error = %err, "Failed to reload the active theme manifest")
            }
        }

        // Step 3: Re-resolve the published variant from the on-disk payload.
        let resolved = Self::resolve_with_fallback(
            self.repo.as_ref(),
            &target_theme_id,
            current.mode,
            settings.contrast,
        )
        .await;

        if resolved != current.resolved {
            self.publish_transaction(resolved).await?;
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

    /// Updates the seed colors of the built-in dynamic theme (`rde-dynamic`).
    ///
    /// # Parameters
    /// - `update`: partial set of seeds; `None` roles keep their current color
    ///
    /// # Behavior
    /// Seeds are validated before anything is written, then `settings.toml` is
    /// persisted atomically and the in-memory snapshot is refreshed. When the
    /// dynamic theme is active every palette is regenerated and republished; a
    /// static active theme keeps its shipped payloads and picks the new seeds up
    /// on the next activation.
    ///
    /// # Errors
    /// Returns [`ThemeError::Settings`] when a seed is rejected, or
    /// [`ThemeError::Io`] when the settings file cannot be written. A rejected
    /// update leaves both the file and the in-memory state untouched.
    pub async fn update_dynamic_theme(
        &self,
        update: DynamicThemeUpdate,
    ) -> Result<ThemeSettings, ThemeError> {
        info!("Updating built-in dynamic theme seeds");

        // Step 1: Apply and validate the update against the persisted settings.
        let mut next = self.theme_settings.read().await.clone();
        update.apply(&mut next)?;

        // Step 2: Persist first; the settings file is the source of truth.
        self.repo.save_settings(&next).await?;

        // Step 3: Refresh the in-memory snapshot.
        *self.theme_settings.write().await = next.clone();

        // Step 4: Republish the dynamic theme when it is the active theme.
        self.republish_if_dynamic().await?;

        Ok(next)
    }

    /// Re-resolves and republishes the built-in dynamic theme when it is active.
    ///
    /// # Errors
    /// Propagates publication failures from the cache write path.
    async fn republish_if_dynamic(&self) -> Result<(), ThemeError> {
        let current = self.current_state().await;
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

        let settings = self.theme_settings.read().await.clone();
        let resolved = Self::resolve_with_fallback(
            self.repo.as_ref(),
            &ThemeId::builtin_dynamic(),
            current.mode,
            settings.contrast,
        )
        .await;

        if resolved != current.resolved {
            self.publish_transaction(resolved).await?;
        } else {
            debug!("Dynamic theme payload is unchanged; skipping publication");
        }

        Ok(())
    }

    /// Performs the atomic publication transaction honoring the hard ordering invariant:
    /// **Write file first, then bump generation, then emit signal.**
    ///
    /// # Parameters
    /// - `resolved`: new palette to publish
    ///
    /// # Errors
    /// Returns [`ThemeError::Serialization`] only when the cache payload cannot
    /// be encoded; adapter failures are logged and do not abort publication.
    async fn publish_transaction(&self, resolved: ResolvedTheme) -> Result<(), ThemeError> {
        // Step 0: Serialize publications. Two requests must never interleave
        // their renders, deletions, and desktop notifications, or the desktop
        // could end up applying a generation whose scheme was already deleted.
        let _publication = self.publish_guard.lock().await;

        // Step 1: Invariant Step A: Write the published theme cache atomically first.
        if let Err(err) = Self::write_current_json(&self.cache_path, &resolved) {
            warn!(error = %err, "Failed to write published theme cache; proceeding with in-memory state");
        }

        // Step 2: Invariant Step B: Publish the palette and bump the generation.
        *self.resolved_theme.write().await = resolved.clone();
        let generation = self.generation.fetch_add(1, Ordering::SeqCst) + 1;

        // Step 3: Render and atomically write adapter outputs under the name of
        // the new generation, deleting the artifacts of the previous one.
        let applied = Self::apply_adapters(&self.adapter_registry, &resolved, generation).await;

        // Step 4: Shell out to KDE if the Qt adapter installed the new scheme.
        if applied.contains(&KDE_ADAPTER_NAME) {
            let scheme_name = unique_theme_name(&resolved.theme_id, &resolved.variant, generation);
            Self::maybe_apply_kde(&self.session_env, &scheme_name);
        }

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

    /// Returns whether a filesystem event should trigger a theme reload.
    ///
    /// # Parameters
    /// - `kind`: kind of the filesystem event reported by `notify`
    ///
    /// # Returns
    /// `false` for [`notify::EventKind::Access`] events, because the service's
    /// own reads would otherwise reload the theme in an endless loop.
    fn is_reload_trigger(kind: &notify::EventKind) -> bool {
        !matches!(kind, notify::EventKind::Access(_))
    }

    /// Internal debounced watch loop using `notify`.
    async fn watch_loop(&self) {
        use notify::{Event, RecursiveMode, Watcher};

        let (tx, mut rx) = tokio::sync::mpsc::channel(64);

        let mut watcher =
            match notify::recommended_watcher(move |res: Result<Event, notify::Error>| {
                if let Ok(event) = res {
                    // Step 1: Ignore pure read notifications. Reloading reads
                    // `themes.toml` and the settings file, so reacting to our own
                    // reads would keep triggering reloads forever.
                    if Self::is_reload_trigger(&event.kind) {
                        let _ = tx.blocking_send(event);
                    }
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
    use crate::{
        backend::KdeAdapter,
        domain::{
            identity::{AdapterId, VariantId},
            manifest::{ContrastLevel, RelativePath, ThemeMode, VariantDescriptor},
            registry::{ThemeEntry, ThemeLocation, ThemeRegistry, ThemeSource},
            resolved::{Color, ColorSeeds, Motion, Shape, Typography, VariantKind},
        },
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

            // Return a dynamic fallback derived from the repository's current seeds,
            // mirroring the disk repository's seed handling.
            let settings = self.settings.lock().unwrap().clone();
            let seeds = settings.dynamic.color_seeds();
            let colors = crate::backend::material::compute_color_roles(
                &seeds,
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
            &ColorSeeds::uniform(&Color::new("#123456").unwrap()),
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
            AdapterRegistry::default(),
            cache_file.clone(),
            settings_file,
            themes_dir,
        )
        .await
        .unwrap();

        // Set active to theme_a; the choice is persisted for the next startup.
        service.set_active(theme_a.clone()).await.unwrap();
        {
            let settings = repo.settings.lock().unwrap();
            assert_eq!(settings.active_theme.as_ref(), Some(&theme_a));
        }
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
    async fn test_activate_theme_switches_to_an_explicit_variant() {
        let temp = tempfile::tempdir().unwrap();
        let repo = Arc::new(FakeRepo::new());
        let theme_a = ThemeId::new("theme-a").unwrap();
        let dark_var = VariantId::new("dark").unwrap();
        let light_var = VariantId::new("light").unwrap();

        // Step 1: Register theme-a with a dark and a light variant.
        repo.registry
            .lock()
            .unwrap()
            .themes
            .insert(theme_a.clone(), ThemeEntry::default());
        let mut variants = BTreeMap::new();
        for (variant, mode) in [(&dark_var, ThemeMode::Dark), (&light_var, ThemeMode::Light)] {
            variants.insert(
                variant.clone(),
                VariantDescriptor {
                    mode,
                    contrast: ContrastLevel::Normal,
                    display_name: None.into(),
                    file_path: RelativePath::new("variant.json").unwrap(),
                    preview: None.into(),
                },
            );
        }
        repo.manifests.lock().unwrap().insert(
            theme_a.clone(),
            ThemeManifest {
                schema_version: 1,
                name: theme_a.clone(),
                display_name: "Theme A".into(),
                description: "A".into(),
                author: None.into(),
                license: None.into(),
                version: "1.0.0".into(),
                variants,
                default_variant: dark_var.clone(),
            },
        );
        repo.resolved_map.lock().unwrap().insert(
            (theme_a.clone(), light_var.clone()),
            sample_resolved(&theme_a, &light_var),
        );

        let service = ThemeService::startup(
            repo.clone(),
            AdapterRegistry::default(),
            temp.path().join("current.json"),
            temp.path().join("settings.toml"),
            temp.path().join("themes"),
        )
        .await
        .unwrap();

        // Step 2: Activating the light variant persists the theme and derives the
        // appearance mode from the variant descriptor.
        let generation_before = service.current_state().await.generation;
        service
            .activate_theme(theme_a.clone(), light_var.clone())
            .await
            .unwrap();

        let state = service.current_state().await;
        assert_eq!(state.active.as_ref(), Some(&theme_a));
        assert_eq!(state.mode, ThemeMode::Light);
        assert_eq!(state.resolved.variant, light_var);
        assert_eq!(state.generation, generation_before + 1);
        assert_eq!(service.theme_mode().await, ThemeMode::Light);
        assert_eq!(service.theme_manifest().await.name, theme_a);
        assert_eq!(repo.settings.lock().unwrap().active_theme, Some(theme_a));

        // Step 3: Re-activating the same variant is idempotent.
        service
            .activate_theme(
                ThemeId::new("theme-a").unwrap(),
                VariantId::new("light").unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(
            service.current_state().await.generation,
            generation_before + 1
        );
    }

    #[tokio::test]
    async fn test_update_dynamic_theme_persists_and_republishes() {
        let temp = tempfile::tempdir().unwrap();
        let cache_file = temp.path().join("current.json");
        let settings_file = temp.path().join("settings.toml");
        let themes_dir = temp.path().join("themes");

        let repo = Arc::new(FakeRepo::new());
        let service = Arc::new(
            ThemeService::startup(
                repo.clone(),
                AdapterRegistry::default(),
                cache_file,
                settings_file,
                themes_dir,
            )
            .await
            .unwrap(),
        );

        // The built-in dynamic theme is active right after startup.
        let generation_before = service.current_state().await.generation;
        let mut sub = service.subscribe_theme_changed();

        // Step 1: Update every seed and expect a republish.
        let settings = service
            .update_dynamic_theme(DynamicThemeUpdate {
                primary: Some("#006a6a".to_string()),
                secondary: Some("#6750a4".to_string()),
                tertiary: Some("#b52700".to_string()),
                error: Some("#b90063".to_string()),
            })
            .await
            .unwrap();
        assert_eq!(settings.dynamic.primary, "#006a6a");

        // The seeds are persisted through the repository, not only held in memory.
        assert_eq!(repo.settings.lock().unwrap().dynamic.secondary, "#6750a4");

        let state_after = service.current_state().await;
        assert_eq!(state_after.generation, generation_before + 1);
        let received = sub.try_recv().expect("republished dynamic theme");
        assert_eq!(received, state_after.resolved);
        assert_eq!(received.kind, VariantKind::Dynamic);
        assert_eq!(
            received.colors,
            crate::backend::material::compute_color_roles(
                &ColorSeeds {
                    primary: Color::new("#006a6a").unwrap(),
                    secondary: Color::new("#6750a4").unwrap(),
                    tertiary: Color::new("#b52700").unwrap(),
                    error: Color::new("#b90063").unwrap(),
                },
                ThemeMode::Dark,
                ContrastLevel::Normal,
            )
        );

        // Step 2: A rejected update must not touch the persisted seeds.
        let rejected = service
            .update_dynamic_theme(DynamicThemeUpdate {
                primary: Some("teal".to_string()),
                ..DynamicThemeUpdate::default()
            })
            .await;
        assert!(matches!(rejected, Err(ThemeError::Settings(_))));
        assert_eq!(service.settings().await.dynamic.primary, "#006a6a");
    }

    #[tokio::test]
    async fn test_set_mode_persists_and_republishes() {
        let temp = tempfile::tempdir().unwrap();
        let repo = Arc::new(FakeRepo::new());
        let service = Arc::new(
            ThemeService::startup(
                repo.clone(),
                AdapterRegistry::default(),
                temp.path().join("current.json"),
                temp.path().join("settings.toml"),
                temp.path().join("themes"),
            )
            .await
            .unwrap(),
        );

        // Startup publishes the default dark appearance.
        let generation_before = service.current_state().await.generation;
        let mut sub = service.subscribe_theme_changed();

        // Step 1: Switching to light persists the preference and republishes.
        service.set_mode(ThemeMode::Light).await.unwrap();
        assert_eq!(service.settings().await.mode, ThemeMode::Light);
        assert_eq!(repo.settings.lock().unwrap().mode, ThemeMode::Light);

        let published = service.current_state().await;
        assert_eq!(published.mode, ThemeMode::Light);
        assert_eq!(published.generation, generation_before + 1);
        let received = sub.try_recv().expect("republished theme on mode change");
        assert_eq!(received, published.resolved);

        // Step 2: Selecting the same mode again neither bumps nor signals.
        service.set_mode(ThemeMode::Light).await.unwrap();
        assert_eq!(
            service.current_state().await.generation,
            published.generation
        );
        assert!(sub.try_recv().is_err());
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
                AdapterRegistry::default(),
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

    #[tokio::test]
    async fn publication_installs_a_new_kde_color_scheme_per_generation() {
        let temp = tempfile::tempdir().unwrap();
        let config_home = temp.path().join("config");
        let data_home = temp.path().join("data");
        let schemes = crate::backend::kde::color_schemes_dir(&data_home);
        std::fs::create_dir_all(&schemes).unwrap();

        // A scheme an earlier generation left behind and one the user installed.
        std::fs::write(schemes.join("rde-dynamic-dark-v0.colors"), "stale").unwrap();
        std::fs::write(schemes.join("Breeze.colors"), "user installed").unwrap();

        let mut registry = AdapterRegistry::default();
        registry.adapters.insert(
            AdapterId::new(KDE_ADAPTER_NAME).unwrap(),
            Box::new(KdeAdapter::new(config_home, data_home)),
        );

        let service = ThemeService::startup(
            Arc::new(FakeRepo::new()),
            registry,
            temp.path().join("current.json"),
            temp.path().join("settings.toml"),
            temp.path().join("themes"),
        )
        .await
        .unwrap();

        // Step 1: Startup is generation 1, so it installs the `v1` scheme named
        // after the theme and variant, and deletes the leftover of the last run.
        let first_dark = schemes.join("rde-dynamic-dark-v1.colors");
        let first_scheme = std::fs::read_to_string(&first_dark).expect("startup scheme");
        assert!(
            first_scheme.contains("Name=rde-dynamic-dark-v1"),
            "{first_scheme}"
        );
        assert!(!schemes.join("rde-dynamic-dark-v0.colors").exists());
        assert!(schemes.join("Breeze.colors").exists());

        // Step 2: Another variant is published under its own name and does not
        // disturb the scheme of the variant that stays on disk.
        service.set_mode(ThemeMode::Light).await.unwrap();
        let light = schemes.join("rde-dynamic-light-v2.colors");
        assert!(light.exists(), "the light variant gets its own scheme");
        assert!(first_dark.exists(), "the dark scheme is still installed");

        // Step 3: Regenerating the dark variant installs generation 3 and deletes
        // the superseded scheme of generation 1.
        service.set_mode(ThemeMode::Dark).await.unwrap();
        let second_dark = schemes.join("rde-dynamic-dark-v3.colors");
        assert!(
            second_dark.exists(),
            "a regenerated variant installs a new scheme"
        );
        assert!(
            !first_dark.exists(),
            "the superseded scheme of the same variant is deleted"
        );
        assert!(light.exists(), "the scheme of the other variant survives");
    }

    #[test]
    fn reload_ignores_read_events() {
        // Our own reads of `themes.toml` must never queue another reload.
        assert!(!ThemeService::is_reload_trigger(
            &notify::EventKind::Access(notify::event::AccessKind::Any)
        ));

        // Writes and creates are the changes the service reacts to.
        assert!(ThemeService::is_reload_trigger(&notify::EventKind::Modify(
            notify::event::ModifyKind::Any
        )));
        assert!(ThemeService::is_reload_trigger(&notify::EventKind::Create(
            notify::event::CreateKind::Any
        )));
    }
}
