use rde_core::errors::RdeResult;
use rde_ipc::{message::Response, socket::IpcClient};

use crate::ipc::server::Server;

impl Server {
    /// Process incoming responses from supervised client services.
    ///
    /// # NOTE
    /// - Responses are generally received in response to requests sent by the daemon.
    ///
    /// # TODO
    /// - Implement transaction/request mapping using `message_id` to route responses back to their originators.
    pub async fn handle_client_response(
        _client: &mut IpcClient,
        response: Response,
    ) -> RdeResult<()> {
        match response {
            Response::Success(success) => {
                tracing::info!("Success response: {}", success.message);
            }
            Response::Error(err) => {
                tracing::error!(
                    "Error response: Code {} - {}",
                    err.error.code,
                    err.error.message
                );
            }
            Response::RegisterAck(ack) => {
                tracing::warn!("Received unexpected RegisterAck: {}", ack.message);
            }
            Response::Status(status) => {
                tracing::info!("Status response: {:?}", status.service);
            }
            Response::ServiceList(list) => {
                tracing::info!("ServiceList response: Count {}", list.count);
            }
            Response::ShutdownAck(ack) => {
                tracing::info!("ShutdownAck response: {}", ack.message);
            }
        }
        Ok(())
    }
}
