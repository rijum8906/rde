use rde_core::errors::RdeResult;
use rde_ipc::{message::ServiceResponse, socket::IpcClient};

use crate::ipc::server::Server;

impl Server {
    /// Process incoming responses from supervised client services.
    pub async fn handle_client_response(
        _client: &mut IpcClient,
        response: ServiceResponse,
    ) -> RdeResult<()> {
        match response {
            ServiceResponse::Alive => {
                tracing::info!("Alive response received from client");
            }
            ServiceResponse::Status(status) => {
                tracing::info!("Status response: {:?}", status);
            }
            ServiceResponse::ShutdownAck(ack) => {
                tracing::info!("ShutdownAck response: {:?}", ack.reason);
            }
        }
        Ok(())
    }
}
