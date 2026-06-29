use std::sync::Arc;

use crate::api::ApiClient;
use crate::config::NetConfig;
use crate::decorate::{NoSession, RequestDecorator, ScCredentials};
use crate::dispatch::Dispatcher;
use crate::error::NetError;
use crate::request::{HttpRequest, HttpResponse, NetStream};
use crate::retry::RetryPolicy;
use crate::storage::StorageClient;
use crate::stream::StreamClient;

const DEFAULT_USER_AGENT: &str =
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36";

/// Единая точка входа в сеть: общий диспетчер (роутер + декоратор) и три
/// типизированных фасада. Доменные методы (поиск, resolve) живут не здесь, а в
/// `sc-raw` поверх этого клиента — `sc-net` остаётся транспортом.
pub struct NetClient {
    dispatcher: Arc<Dispatcher>,
    pub api: ApiClient,
    pub stream: StreamClient,
    pub storage: StorageClient,
}

impl NetClient {
    /// Аноним: декоратор добавляет только User-Agent (сессии нет).
    pub async fn new(config: NetConfig) -> Result<Self, NetError> {
        let user_agent = config
            .user_agent
            .clone()
            .unwrap_or_else(|| DEFAULT_USER_AGENT.to_owned());
        let decorator: Arc<dyn RequestDecorator> =
            Arc::new(ScCredentials::new(Arc::new(NoSession), user_agent));
        Self::assemble(config, decorator).await
    }

    /// С внешним декоратором (DI): сюда `sc-core` подсовывает реальный источник
    /// сессии из `sc-auth`.
    pub async fn with_decorator(
        config: NetConfig,
        decorator: Arc<dyn RequestDecorator>,
    ) -> Result<Self, NetError> {
        Self::assemble(config, decorator).await
    }

    async fn assemble(
        config: NetConfig,
        decorator: Arc<dyn RequestDecorator>,
    ) -> Result<Self, NetError> {
        let router = Arc::new(config.build_router().await?);
        let dispatcher = Arc::new(Dispatcher::new(router, decorator));
        Ok(Self {
            api: ApiClient::new(dispatcher.clone()),
            stream: StreamClient::new(dispatcher.clone()),
            storage: StorageClient::new(dispatcher.clone()),
            dispatcher,
        })
    }

    /// Исполнить произвольный запрос (декорируется + маршрутизируется + retry).
    pub async fn request(&self, req: HttpRequest) -> Result<HttpResponse, NetError> {
        self.dispatcher.send(req).await
    }

    /// То же, но с явной политикой (стримы/большие файлы — `RetryPolicy::none`).
    pub async fn request_with(
        &self,
        req: HttpRequest,
        policy: &RetryPolicy,
    ) -> Result<HttpResponse, NetError> {
        self.dispatcher.send_with(req, policy).await
    }

    /// Скачать тело потоком — для больших файлов с прогрессом (см. [`NetStream`]).
    /// Декорируется и маршрутизируется как обычный запрос; настоящий стрим идёт
    /// по Direct-хостам, прочие деградируют до одночанкового тела.
    pub async fn download(&self, req: HttpRequest) -> Result<NetStream, NetError> {
        self.dispatcher.download(req).await
    }
}
