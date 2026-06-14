pub enum Error {
    // Socket errors
    SocketNotFound(String),

    // Socket Connection errors
    SocketConnectionClosed(String),
    SocketConnectionError(String),

    // Message errors
    InvalidMessage(String),
    MessageTooLarge(usize),
}
