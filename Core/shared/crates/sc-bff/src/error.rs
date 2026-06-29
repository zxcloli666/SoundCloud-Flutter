#[derive(Debug, thiserror::Error)]
pub enum BffError {
    #[error(transparent)]
    Net(#[from] sc_net::NetError),
    #[error("decode: {0}")]
    Decode(String),
    #[error("backend {status}: {path}")]
    Status { status: u16, path: String },
}
