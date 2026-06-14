use std::{io::Read, os::unix::net::UnixStream};

use serde_json::from_slice;

use crate::ipc::transport::request::{self, Request, RequestType};

// handle_stream handles a single stream and parse the buffer
pub fn handle_stream(stream: &mut UnixStream) {
    loop {
        let mut buffer = [0u8; 1024 * 2];
        match stream.read(&mut buffer) {
            Ok(n) => {
                // Handle the message here
                handle_message(&mut buffer[..n]);
            }
            Err(e) => {
                eprintln!("Read error: {}", e);
                break;
            }
        }
    }
}

// handle_message handles a single message and path the data to proper request type
pub fn handle_message(buffer: &mut [u8]) {
    // ✅ Correct: buffer is already &mut [u8], just use it
    let request: Result<request::Request, _> = from_slice(buffer);

    match request {
        Ok(req) => {
            println!("Deserialized: {:?}", req);
            handle_request(req);
        }
        Err(e) => {
            eprintln!("Failed to deserialize: {}", e);
            // Handle error...
        }
    }
}

// handle_request handles a single request
pub fn handle_request(request: Request) {
    match request.request_type {
        RequestType::Window => todo!(),
        RequestType::Screen => todo!(),
    }
}
