//! Приватные serde-DTO платёжного сервиса. Точные формы из
//! `Internal/pay/src/handlers/{checkout,me,redeem}.rs` + `model.rs`.

use serde::Deserialize;

use sc_domain::{Checkout, Entitlement, Order, PayTarget, Plan, Redeem, Subscription};

/// `GET /api/plans` → `{monthly_rub, plans:[PlanView], providers, methods}`.
#[derive(Deserialize)]
pub(crate) struct PlansEnvelope {
    #[serde(default)]
    pub plans: Vec<PlanDto>,
}

#[derive(Deserialize)]
pub(crate) struct PlanDto {
    pub id: String,
    #[serde(default)]
    pub months: i64,
    #[serde(default)]
    pub period_days: i64,
    #[serde(default)]
    pub price_rub: i64,
    #[serde(default)]
    pub savings_pct: i64,
    #[serde(default)]
    pub stars: i64,
}

impl PlanDto {
    pub(crate) fn into_domain(self) -> Plan {
        Plan {
            id: self.id,
            months: self.months,
            period_days: self.period_days,
            price_rub: self.price_rub,
            savings_pct: self.savings_pct,
            stars: self.stars,
        }
    }
}

#[derive(Deserialize)]
pub(crate) struct SubscriptionDto {
    #[serde(default)]
    pub premium: bool,
    #[serde(default)]
    pub premium_until: i64,
    #[serde(default)]
    pub entitlements: Vec<EntitlementDto>,
}

#[derive(Deserialize)]
pub(crate) struct EntitlementDto {
    pub source: String,
    #[serde(default)]
    pub starts_at: i64,
    #[serde(default)]
    pub ends_at: i64,
    #[serde(default)]
    pub recurring: bool,
    #[serde(default)]
    pub auto_renew: bool,
    #[serde(default)]
    pub canceled: bool,
}

impl SubscriptionDto {
    pub(crate) fn into_domain(self) -> Subscription {
        Subscription {
            premium: self.premium,
            premium_until: self.premium_until,
            entitlements: self.entitlements.into_iter().map(EntitlementDto::into_domain).collect(),
        }
    }
}

impl EntitlementDto {
    fn into_domain(self) -> Entitlement {
        Entitlement {
            source: self.source,
            starts_at: self.starts_at,
            ends_at: self.ends_at,
            recurring: self.recurring,
            auto_renew: self.auto_renew,
            canceled: self.canceled,
        }
    }
}

/// Заказ. `id` приходит uuid (list) либо строкой `order_id` (get_order) —
/// принимаем оба ключа.
#[derive(Deserialize)]
pub(crate) struct OrderDto {
    #[serde(alias = "order_id")]
    pub id: String,
    #[serde(default)]
    pub plan_id: String,
    #[serde(default)]
    pub provider: String,
    #[serde(default)]
    pub method: Option<String>,
    #[serde(default)]
    pub status: String,
    #[serde(default)]
    pub currency: String,
    #[serde(default)]
    pub amount_rub: i64,
    #[serde(default)]
    pub amount_minor: Option<i64>,
    #[serde(default)]
    pub recurring: bool,
    #[serde(default)]
    pub pay_url: Option<String>,
    #[serde(default)]
    pub sbp_qr: Option<String>,
    #[serde(default)]
    pub created_at: i64,
    #[serde(default)]
    pub paid_at: Option<i64>,
    #[serde(default)]
    pub granted_at: Option<i64>,
    #[serde(default)]
    pub expires_at: Option<i64>,
    #[serde(default)]
    pub premium_until: Option<i64>,
}

impl OrderDto {
    pub(crate) fn into_domain(self) -> Order {
        Order {
            id: self.id,
            plan_id: self.plan_id,
            provider: self.provider,
            method: self.method,
            status: self.status,
            currency: self.currency,
            amount_rub: self.amount_rub,
            amount_minor: self.amount_minor,
            recurring: self.recurring,
            pay_url: self.pay_url,
            sbp_qr: self.sbp_qr,
            created_at: self.created_at,
            paid_at: self.paid_at,
            granted_at: self.granted_at,
            expires_at: self.expires_at,
            premium_until: self.premium_until,
        }
    }
}

#[derive(Deserialize)]
pub(crate) struct CheckoutDto {
    pub order_id: String,
    #[serde(default)]
    pub provider: String,
    #[serde(default)]
    pub status: String,
    #[serde(default)]
    pub currency: String,
    #[serde(default)]
    pub amount_rub: i64,
    #[serde(default)]
    pub amount_minor: i64,
    #[serde(default)]
    pub recurring: bool,
    #[serde(default)]
    pub pay_url: Option<String>,
    #[serde(default)]
    pub pay_targets: Vec<PayTargetDto>,
    #[serde(default)]
    pub sbp_qr: Option<String>,
    #[serde(default)]
    pub expires_at: i64,
}

#[derive(Deserialize)]
pub(crate) struct PayTargetDto {
    pub kind: String,
    pub url: String,
}

impl CheckoutDto {
    pub(crate) fn into_domain(self) -> Checkout {
        Checkout {
            order_id: self.order_id,
            provider: self.provider,
            status: self.status,
            currency: self.currency,
            amount_rub: self.amount_rub,
            amount_minor: self.amount_minor,
            recurring: self.recurring,
            pay_url: self.pay_url,
            pay_targets: self
                .pay_targets
                .into_iter()
                .map(|t| PayTarget {
                    kind: t.kind,
                    url: t.url,
                })
                .collect(),
            sbp_qr: self.sbp_qr,
            expires_at: self.expires_at,
        }
    }
}

#[derive(Deserialize)]
pub(crate) struct RedeemDto {
    #[serde(default)]
    pub plan_id: Option<String>,
    #[serde(default)]
    pub period_days: Option<i64>,
    #[serde(default)]
    pub premium_until: Option<i64>,
}

impl RedeemDto {
    pub(crate) fn into_domain(self) -> Redeem {
        Redeem {
            plan_id: self.plan_id,
            period_days: self.period_days,
            premium_until: self.premium_until,
        }
    }
}
