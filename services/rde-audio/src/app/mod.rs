//! App Module
//!
//! The definatoin of app

mod ipc_thread;

use std::time::Instant;

use rde_core::utils::ipc_task_handler::IpcTaskHandler;

#[derive(Default)]
pub struct App {
    // ---------- Life Cycle ----------
    is_running: bool,
    stated_at: Option<Instant>,

    // ---------- IPC Thread ----------
    ipc_thread: Option<IpcTaskHandler>,
}

impl App {
    /// This is a start the app and block the code to get a SIGTERM signal
    pub fn start(&mut self) {
        self.is_running = true;
        self.stated_at = Some(Instant::now());

        // create a new thread
        self.handle_ipc_thread();
    }

    pub fn stop(&mut self) {
        // tell the ipc_thread to stop
        if let Some(task_handler) = &self.ipc_thread {
            task_handler.cancellation_token.cancel();
        };
    }
}
