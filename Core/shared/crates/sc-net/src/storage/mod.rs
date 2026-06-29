//! Фасад хранилища (`storage.*`): готовые файлы треков и обложки. Через общий
//! роутер. Типизированные методы — слоем выше.

use std::sync::Arc;

use crate::dispatch::Dispatcher;
use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse};
use crate::retry::RetryPolicy;

pub struct StorageClient {
    dispatcher: Arc<Dispatcher>,
}

impl StorageClient {
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
