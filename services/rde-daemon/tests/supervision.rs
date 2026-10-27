//! # Supervision Socket Integration Tests
//!
//! Exercises the daemon through the same interface a real service uses: bind a
//! supervision socket, connect an [`UnixIpcClient`], register, and disconnect.
//!
//! ## Features
//! - Registration handshake returns a successful `RegisterAck`
//! - Registered services appear in the daemon registry
//! - Disconnecting a service removes it from the registry
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use rde_ipc::client::IpcClient;
use std::time::Duration;

use rde_core::errors::{RdeError, RdeResult};
use rde_daemon::{app::App, ipc::server::Server};
use rde_ipc::{
    error::IpcError,
    message::{
        AckResponse, DaemonResponse, Message, MessagePayload, RegisterRequest, ServiceRequest,
    },
    socket::UnixIpcClient,
};

/// Polls `condition` until it holds or the timeout elapses.
async fn wait_until(mut condition: impl FnMut() -> bool) -> bool {
    for _ in 0..100 {
        if condition() {
            return true;
        }
        tokio::time::sleep(Duration::from_millis(20)).await;
    }

    false
}

/// Converts an IPC error into the daemon's domain error.
fn ipc_error(error: IpcError) -> RdeError {
    RdeError::Socket(error.to_string())
}

/// A service can register, then is deregistered when its connection closes.
#[tokio::test]
async fn registration_is_acknowledged_and_cleaned_up_on_disconnect() -> RdeResult<()> {
    let temp_dir = tempfile::tempdir().map_err(RdeError::Io)?;
    let socket_path = temp_dir.path().join("rde-daemon-test.sock");

    // 1. Start a supervisor on a private socket.
    let server = Server::new_with_path(socket_path.clone())?;

    // 2. Connect as a service would.
    let mut client = UnixIpcClient::default();
    client.connect(&socket_path).await.map_err(ipc_error)?;

    // 3. Send the registration handshake.
    client
        .send_service_request(ServiceRequest::Register(RegisterRequest {
            name: "test-service".to_string(),
            pid: std::process::id(),
            version: "0.1.0".to_string(),
            capabilities: Vec::new(),
        }))
        .await
        .map_err(ipc_error)?;

    // 4. Expect a successful acknowledgement.
    let acknowledgement: Message = client.recv().await.map_err(ipc_error)?;
    match acknowledgement.payload {
        MessagePayload::DaemonResponse(DaemonResponse::RegisterAck(AckResponse {
            success,
            ..
        })) => assert!(success, "daemon rejected a valid registration"),
        other => panic!("expected a RegisterAck response, received {other:?}"),
    }

    // 5. The service must be visible in the registry.
    let registered = wait_until(|| {
        App::with_global(|app| app.service("test-service").is_some()).unwrap_or(false)
    })
    .await;
    assert!(
        registered,
        "registered service was not added to the registry"
    );

    // 6. Closing the connection must release the registry entry.
    drop(client);
    let cleaned_up = wait_until(|| {
        App::with_global(|app| app.service("test-service").is_none()).unwrap_or(false)
    })
    .await;
    assert!(
        cleaned_up,
        "service remained in the registry after disconnecting"
    );

    server.shutdown()?;
    Ok(())
}
