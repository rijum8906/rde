use rde_core::errors::RdeResult;
use rde_ipc::{message::DaemonResponse, socket::IpcClient};

use crate::app::handler::Handler;

impl Handler {
    /// Process responses received back from the daemon supervisor.
    pub async fn handle_daemon_response(
        &mut self,
        response: DaemonResponse,
        _client: &mut IpcClient,
    ) -> RdeResult<()> {
        match response {
            DaemonResponse::RegisterAck(ack) => {
                if ack.success {
                    tracing::info!("Successfully registered with Daemon");
                } else {
                    tracing::error!("Registration failed: {:?}", ack.reason);
                }
            }
        }
        Ok(())
    }
}
