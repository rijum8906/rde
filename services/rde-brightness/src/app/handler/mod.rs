use rde_core::errors::RdeResult;
use rde_ipc::{
    message::{Message, MessagePayload},
    socket::IpcClient,
};

pub mod request;
pub mod response;

pub struct Handler {
    pub service_name: String,
}

impl Handler {
    pub fn new(service_name: &str) -> Self {
        Self {
            service_name: service_name.to_string(),
        }
    }

    /// Route and handle incoming messages from the daemon supervisor.
    pub async fn handle_message(&mut self, msg: Message, client: &mut IpcClient) -> RdeResult<()> {
        match msg.payload {
            MessagePayload::DaemonRequest(request) => {
                self.handle_daemon_request(request, client).await
            }
            MessagePayload::DaemonResponse(response) => {
                self.handle_daemon_response(response, client).await
            }
            _ => {
                tracing::warn!(
                    "Service received unexpected payload category from daemon: {:?}",
                    msg.payload
                );
                Ok(())
            }
        }
    }
}
