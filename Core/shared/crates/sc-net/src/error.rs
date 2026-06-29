#[derive(Debug, thiserror::Error)]
pub enum NetError {
    #[error("http status {0}")]
    Status(u16),
    #[error("all transports exhausted for `{0}`")]
    Exhausted(String),
    #[error("invalid url: {0}")]
    InvalidUrl(String),
    #[error("decode: {0}")]
    Decode(String),
    #[error("io: {0}")]
    Io(String),
    #[error(transparent)]
    Reqwest(#[from] reqwest::Error),
    #[error("retries exhausted after {0} attempts: {1}")]
    RetriesExhausted(u32, Box<NetError>),
    #[error("not implemented")]
    NotImplemented,
}
