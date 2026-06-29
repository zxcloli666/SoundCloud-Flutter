//! FRB-функции платёжного слоя STAR. Зеркалит стиль [`crate::data`].

use crate::api::{BridgeError, bridge};
use crate::dto_pay::{CheckoutDto, OrderDto, PlanDto, RedeemDto, SubscriptionDto};
use crate::map_pay;

pub fn pay_plans() -> Result<Vec<PlanDto>, BridgeError> {
    let b = bridge()?;
    let plans = b.rt.block_on(b.core.pay_plans())?;
    Ok(plans.into_iter().map(map_pay::plan).collect())
}

pub fn pay_subscription() -> Result<SubscriptionDto, BridgeError> {
    let b = bridge()?;
    Ok(map_pay::subscription(b.rt.block_on(b.core.pay_subscription())?))
}

pub fn pay_orders() -> Result<Vec<OrderDto>, BridgeError> {
    let b = bridge()?;
    let orders = b.rt.block_on(b.core.pay_orders())?;
    Ok(orders.into_iter().map(map_pay::order).collect())
}

pub fn pay_order(id: String) -> Result<Option<OrderDto>, BridgeError> {
    let b = bridge()?;
    let order = b.rt.block_on(b.core.pay_order(&id))?;
    Ok(order.map(map_pay::order))
}

pub fn pay_checkout(
    plan_id: String,
    provider: String,
    method: Option<String>,
    recurring: Option<bool>,
) -> Result<CheckoutDto, BridgeError> {
    let b = bridge()?;
    let checkout = b.rt.block_on(b.core.pay_checkout(
        &plan_id,
        &provider,
        method.as_deref(),
        recurring,
    ))?;
    Ok(map_pay::checkout(checkout))
}

pub fn pay_redeem(code: String) -> Result<RedeemDto, BridgeError> {
    let b = bridge()?;
    Ok(map_pay::redeem(b.rt.block_on(b.core.pay_redeem(&code))?))
}

pub fn pay_cancel(source: String) -> Result<(), BridgeError> {
    let b = bridge()?;
    b.rt.block_on(b.core.pay_cancel(&source))?;
    Ok(())
}
