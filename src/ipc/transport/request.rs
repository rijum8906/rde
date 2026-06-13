pub enum RequestType {
    Window,
    Screen,
}

pub enum RequestMethod {
    GET,
    SET,
    UPDATE,
}

pub struct Request {
    pub request_type: RequestType,
    pub request_method: RequestMethod,
    pub data: [u8],
}
