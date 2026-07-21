use rde_core::errors::RdeResult;

use crate::app::Application;

impl Application {
    pub async fn shutdown(&mut self) -> RdeResult<()> {
        if self.is_running {
            if self.is_conneced {
                let mut handler_guard = self.handler.lock().await;
                if let Some(ref mut h) = *handler_guard {
                    if let Err(e) = h.shutdown().await {
                        tracing::error!("Failed to shutdown IPC handler: {}", e);
                    }
                }
                self.is_conneced = false;
            }
            self.is_running = false;
            self.start_time = None;
        }

        Ok(())
    }
}
