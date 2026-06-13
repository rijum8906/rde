pub struct Response {
    pub success: bool,
    pub error: Option<String>,
    pub data: [u8],
}
