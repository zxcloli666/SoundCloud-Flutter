#[derive(Debug, thiserror::Error)]
pub enum RawError {
    #[error(transparent)]
    Net(#[from] sc_net::NetError),
    #[error("soundcloud: {0}")]
    SoundCloud(String),
    #[error("client_id: {0}")]
    ClientId(String),
    #[error("stream: {0}")]
    Stream(String),
}
