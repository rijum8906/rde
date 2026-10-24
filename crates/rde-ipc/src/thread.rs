use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

use crate::IpcCommand;

pub struct IpcThread {
    pub tx: mpsc::Sender<IpcCommand>,
    pub handle: tokio::task::JoinHandle<()>,
    pub cancellation_token: CancellationToken,
}
