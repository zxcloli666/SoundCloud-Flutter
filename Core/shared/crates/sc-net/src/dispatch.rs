//! Диспетчер — общий движок фасадов: декорирует запрос и гонит через роутер.
//! Один на клиента, шарится между `api`/`stream`/`storage` фасадами.

use std::sync::Arc;

use crate::decorate::RequestDecorator;
use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse, NetStream};
use crate::retry::RetryPolicy;
use crate::route::Router;

pub(crate) struct Dispatcher {
    router: Arc<Router>,
    decorator: Arc<dyn RequestDecorator>,
}

impl Dispatcher {
    pub(crate) fn new(router: Arc<Router>, decorator: Arc<dyn RequestDecorator>) -> Self {
        Self { router, decorator }
    }

    pub(crate) async fn send(&self, req: HttpRequest) -> Result<HttpResponse, NetError> {
        self.router.execute(&self.decorator.decorate(req)).await
    }

    pub(crate) async fn send_with(
        &self,
        req: HttpRequest,
        policy: &RetryPolicy,
    ) -> Result<HttpResponse, NetError> {
        self.router
            .execute_with(&self.decorator.decorate(req), policy)
            .await
    }

    pub(crate) async fn download(&self, req: HttpRequest) -> Result<NetStream, NetError> {
        self.router.download(&self.decorator.decorate(req)).await
    }
}
