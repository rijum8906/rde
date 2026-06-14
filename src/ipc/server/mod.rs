pub mod handler;

use std::{
    fs::remove_file,
    os::unix::net::UnixListener,
    sync::{Arc, atomic::AtomicBool},
};

use crate::ipc::{self, server::handler::handle_stream};

// ServerConfig contains the configuration for the Unix Listener
pub struct ServerConfig {
    pub socket_path: String,
    pub max_connections: usize,
    pub max_buffer_size: usize,
}

// Server is the main server struct that holds the UnixListener and acts as the main Server
pub struct Server {
    pub listener: Option<UnixListener>,
    pub running: Arc<AtomicBool>,
}

impl Server {
    // new creates a new Server
    pub fn new(config: ServerConfig) -> Result<ipc::server::Server, ipc::transport::error::Error> {
        // Clean the path
        remove_file(&config.socket_path).ok();

        // Bind the listener
        let listener = UnixListener::bind(&config.socket_path).unwrap();
        Ok(Server {
            listener: Some(listener),
            running: Arc::new(AtomicBool::new(true)),
        })
    }

    // start starts the server
    pub fn start(&mut self) {
        let listener = self.listener.take().unwrap();

        tokio::spawn(async move {
            loop {
                match listener.accept() {
                    Ok((mut stream, _)) => {
                        tokio::spawn(async move {
                            handle_stream(&mut stream);
                        });
                    }
                    Err(e) => {
                        eprintln!("Accept error: {}", e);
                        break;
                    }
                }
            }
        });
    }
}
