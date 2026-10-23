use tokio_util::sync::CancellationToken;

pub struct IpcTaskHandler {
    pub handle: Option<tokio::task::JoinHandle<()>>,
    pub cancellation_token: CancellationToken,
}

impl Default for IpcTaskHandler {
    fn default() -> Self {
        Self::new()
    }
}

impl IpcTaskHandler {
    pub fn new() -> Self {
        Self {
            handle: None,
            cancellation_token: CancellationToken::new(),
        }
    }
}
