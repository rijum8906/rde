use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub enum RequestType {
    Window,
    Screen,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum RequestMethod {
    GET,
    SET,
    EXECUTE,
    UPDATE,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Request {
    pub request_type: RequestType,
    pub request_method: RequestMethod,
    pub data: serde_json::Value,
}
