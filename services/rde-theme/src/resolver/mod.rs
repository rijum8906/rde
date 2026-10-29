//! # Theme Resolvers
//!
//! Turns a set of seed colors into a [`ResolvedTheme`] with a pluggable
//! algorithm, and keeps every algorithm named in a registry so a manifest can
//! select one without the service knowing which implementation runs.

pub mod rdtr;

use std::collections::HashMap;

use crate::{
    domain::{ColorSeeds, ResolvedTheme, ThemeMode, identity::ResolverId},
    theme_store::ThemeError,
};

/// An algorithm that turns four seeds into a resolved palette.
///
/// Pure: no IO, no global state, deterministic. Implementations live in
/// `resolver/<name>.rs` — one file per algorithm.
pub trait Resolver: Send + Sync {
    fn id(&self) -> ResolverId;
    fn resolve(&self, seeds: &ColorSeeds, mode: ThemeMode) -> Result<ResolvedTheme, ThemeError>;
}

/// The registry of all resolvers known to this build.
///
/// Built once, from `app.rs`, and immutable thereafter. Adding an
/// algorithm means adding one file and one `insert` line in `build()`.
pub struct ResolverRegistry {
    resolvers: HashMap<ResolverId, Box<dyn Resolver>>,
    default_id: ResolverId,
}

impl ResolverRegistry {
    pub fn build() -> Self {
        let mut resolvers: HashMap<ResolverId, Box<dyn Resolver>> = HashMap::new();

        let default = rdtr::RdeDefaultThemeResolver::default();
        let default_id = default.id();
        resolvers.insert(default_id.clone(), Box::new(default));

        // Add resolvers here, one line each:
        // let mono = mono::MonoResolver::default();
        // resolvers.insert(mono.id(), Box::new(mono));

        Self {
            resolvers,
            default_id,
        }
    }

    pub fn get(&self, id: &ResolverId) -> Option<&dyn Resolver> {
        self.resolvers.get(id).map(|b| b.as_ref())
    }

    pub fn get_or_default(&self, id: Option<&ResolverId>) -> &dyn Resolver {
        id.and_then(|id| self.get(id))
            .unwrap_or_else(|| self.default_resolver())
    }

    pub fn default_resolver(&self) -> &dyn Resolver {
        // Invariant: `default_id` is always inserted in `build()`.
        self.resolvers
            .get(&self.default_id)
            .map(|b| b.as_ref())
            .expect("invariant: default resolver missing from registry")
    }

    pub fn ids(&self) -> impl Iterator<Item = &ResolverId> {
        self.resolvers.keys()
    }
}
