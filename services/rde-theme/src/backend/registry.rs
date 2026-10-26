//! Adapter Registry

use std::sync::Arc;

use crate::backend::adapter::Adapter;

#[derive(Default)]
pub struct AdapterRegistry {
    pub adapters: Vec<Arc<dyn Adapter>>,
}

impl AdapterRegistry {
    pub fn build() -> Self {
        // TODO: qt adapter
        // let qt_adapter = QtAdapter::default();

        // TODO: gtk adapter
        // let gtk_adapter - GtkAdapter::default();

        Self { adapters: vec![] }
    }
}
