use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct Response {
    pub success: bool,
    pub error: Option<String>,
    pub data: serde_json::Value,
}
