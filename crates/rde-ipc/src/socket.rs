use std::os::unix::net::UnixStream;

use anyhow::Result;

pub struct IPCSocket {
    /// File descriptor for the socket.
    pub fd: UnixStream,
}

impl IPCSocket {
    pub fn new() -> Result<Self> {
        Err(anyhow::anyhow!("not implemented"))
    }
}
