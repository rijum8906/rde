//! RDE Default Theme Resolver.

use crate::{
    adapter::{compute_color_roles, resolvers::Resolver},
    domain::{
        ContrastLevel, Motion, ResolvedTheme, Shape, ThemeId, Typography, VariantId, VariantKind,
        identity::ResolverId,
    },
};

#[derive(Debug, Default)]
pub struct RdeDefaultThemeResolver {}

pub const RDE_DEFAULT_THEME_RESOLVER_ID: &str = "rde-default";

impl Resolver for RdeDefaultThemeResolver {
    fn id(&self) -> crate::domain::identity::ResolverId {
        ResolverId::new(RDE_DEFAULT_THEME_RESOLVER_ID).unwrap()
    }

    fn resolve(
        &self,
        seeds: &crate::domain::ColorSeeds,
        mode: crate::domain::ThemeMode,
    ) -> Result<ResolvedTheme, crate::theme_store::ThemeError> {
        let color_roles = compute_color_roles(seeds, mode, ContrastLevel::Normal);

        Ok(ResolvedTheme {
            theme_id: ThemeId::builtin_dynamic(),
            typography: Typography::default(),
            variant: VariantId::new("default").unwrap(),
            colors: color_roles,
            motion: Motion::default(),
            schema_version: 1,
            kind: VariantKind::Dynamic,
            shape: Shape::default(),
        })
    }
}
