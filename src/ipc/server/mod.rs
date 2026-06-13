use std::os::unix::net::UnixListener;

pub struct Server {
    pub listener: UnixListener,
}
