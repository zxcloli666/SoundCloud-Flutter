//! Фасад нашего BFF (`api.*`). Тонкий: декорирует и маршрутизирует запрос.
//! Типизированные доменные методы строятся поверх него (в `sc-raw`/`sc-core`),
//! чтобы `sc-net` оставался транспортом.

use std::sync::Arc;

use crate::dispatch::Dispatcher;
use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse};
use crate::retry::RetryPolicy;

pub struct ApiClient {
    dispatcher: Arc<Dispatcher>,
}

impl ApiClient {
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
