//! Фасад стриминга (`stream.*`). Качает потоки/сегменты через общий роутер.
//! Выбор источника и формата (включая не-AAC пресеты) — НЕ здесь, а в `sc-raw`:
//! так не-AAC не утекает к плееру, m4a-инвариант держится в `sc-cache`/`sc-core`.

use std::sync::Arc;

use crate::dispatch::Dispatcher;
use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse};
use crate::retry::RetryPolicy;

pub struct StreamClient {
    dispatcher: Arc<Dispatcher>,
}

impl StreamClient {
    pub(crate) fn new(dispatcher: Arc<Dispatcher>) -> Self {
        Self { dispatcher }
    }

    pub async fn request(&self, req: HttpRequest) -> Result<HttpResponse, NetError> {
        self.dispatcher.send(req).await
    }

    pub async fn request_with(
        &self,
        req: HttpRequest,
        policy: &RetryPolicy,
    ) -> Result<HttpResponse, NetError> {
        self.dispatcher.send_with(req, policy).await
    }
}
