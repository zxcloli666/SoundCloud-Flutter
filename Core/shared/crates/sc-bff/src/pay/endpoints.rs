use serde::Serialize;

use sc_domain::{Checkout, Order, Plan, Redeem, Subscription};

use crate::error::BffError;
use crate::pay::client::PayClient;
use crate::pay::dto::{
    CheckoutDto, OrderDto, PlanDto, PlansEnvelope, RedeemDto, SubscriptionDto,
};

#[derive(Serialize)]
struct CheckoutBody<'a> {
    plan_id: &'a str,
    provider: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    method: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    recurring: Option<bool>,
}

#[derive(Serialize)]
struct CancelBody<'a> {
    source: &'a str,
}

#[derive(Serialize)]
struct RedeemBody<'a> {
    code: &'a str,
}

impl PayClient {
    /// Каталог планов (`GET /api/plans`, без сессии).
    pub async fn plans(&self) -> Result<Vec<Plan>, BffError> {
        let env: PlansEnvelope = self.get_json("/api/plans").await?;
        Ok(env.plans.into_iter().map(PlanDto::into_domain).collect())
    }

    /// Состояние подписки (`GET /api/me/subscription`).
    pub async fn subscription(&self) -> Result<Subscription, BffError> {
        let dto: SubscriptionDto = self.get_json("/api/me/subscription").await?;
        Ok(dto.into_domain())
    }

    /// История заказов (`GET /api/me/orders`).
    pub async fn orders(&self) -> Result<Vec<Order>, BffError> {
        let dtos: Vec<OrderDto> = self.get_json("/api/me/orders").await?;
        Ok(dtos.into_iter().map(OrderDto::into_domain).collect())
    }

    /// Один заказ для поллинга после чекаута (`GET /api/orders/{id}`).
    /// `Ok(None)` если не найден/чужой (404).
    pub async fn order(&self, id: &str) -> Result<Option<Order>, BffError> {
        let path = format!("/api/orders/{}", crate::client::enc(id));
        let dto: Option<OrderDto> = self.get_optional(&path).await?;
        Ok(dto.map(OrderDto::into_domain))
    }

    /// Создать заказ (`POST /api/checkout`). `provider` = platega|cryptobot|
    /// tgstars; `method` — суб-метод platega (sbp/…); `recurring` — для Stars m1.
    pub async fn checkout(
        &self,
        plan_id: &str,
        provider: &str,
        method: Option<&str>,
        recurring: Option<bool>,
    ) -> Result<Checkout, BffError> {
        let body = CheckoutBody {
            plan_id,
            provider,
            method,
            recurring,
        };
        let dto: CheckoutDto = self.post_json("/api/checkout", &body).await?;
        Ok(dto.into_domain())
    }

    /// Активировать код (`POST /api/redeem`).
    pub async fn redeem(&self, code: &str) -> Result<Redeem, BffError> {
        let dto: RedeemDto = self.post_json("/api/redeem", &RedeemBody { code }).await?;
        Ok(dto.into_domain())
    }

    /// Отключить авто-продление источника (`POST /api/subscription/cancel`).
    /// `source` = platega|cryptobot|tgstars|code (boosty/admin не отменяются).
    pub async fn cancel(&self, source: &str) -> Result<(), BffError> {
        self.post_ok("/api/subscription/cancel", &CancelBody { source }).await
    }
}
