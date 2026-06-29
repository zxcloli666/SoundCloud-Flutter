//! Платёжный слой STAR рантайма: планы, подписка, заказы, чекаут, коды.
//! Тонкие пасс-тру к [`sc_bff::PayClient`].

use sc_domain::{Checkout, Order, Plan, Redeem, Subscription};

use crate::{CoreError, ScRuntime};

impl ScRuntime {
    pub async fn pay_plans(&self) -> Result<Vec<Plan>, CoreError> {
        Ok(self.pay().plans().await?)
    }

    pub async fn pay_subscription(&self) -> Result<Subscription, CoreError> {
        Ok(self.pay().subscription().await?)
    }

    pub async fn pay_orders(&self) -> Result<Vec<Order>, CoreError> {
        Ok(self.pay().orders().await?)
    }

    pub async fn pay_order(&self, id: &str) -> Result<Option<Order>, CoreError> {
        Ok(self.pay().order(id).await?)
    }

    pub async fn pay_checkout(
        &self,
        plan_id: &str,
        provider: &str,
        method: Option<&str>,
        recurring: Option<bool>,
    ) -> Result<Checkout, CoreError> {
        Ok(self.pay().checkout(plan_id, provider, method, recurring).await?)
    }

    pub async fn pay_redeem(&self, code: &str) -> Result<Redeem, CoreError> {
        Ok(self.pay().redeem(code).await?)
    }

    pub async fn pay_cancel(&self, source: &str) -> Result<(), CoreError> {
        Ok(self.pay().cancel(source).await?)
    }
}
