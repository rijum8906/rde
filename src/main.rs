use rde::ipc::server::{Server, ServerConfig};

#[tokio::main] // ← This macro makes main async
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Create and start the server
    let server_config = ServerConfig {
        max_buffer_size: 2 * 1024,
        socket_path: "".to_string(),
        max_connections: 100,
    };
    let mut server = Server::new(server_config).unwrap();
    server.start();

    print!("Hello, World!");
    Ok(())
}
