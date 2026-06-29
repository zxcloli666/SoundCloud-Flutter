use serde::{Deserialize, Serialize};

/// Тарифный план STAR (`GET /api/plans`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Plan {
    pub id: String,
    pub months: i64,
    pub period_days: i64,
    pub price_rub: i64,
    pub savings_pct: i64,
    pub stars: i64,
}

/// Энтайтлмент: одна линия подписки (источник + срок).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Entitlement {
    pub source: String,
    pub starts_at: i64,
    pub ends_at: i64,
    pub recurring: bool,
    pub auto_renew: bool,
    pub canceled: bool,
}

/// Состояние подписки из леджера pay (`GET /api/me/subscription`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Subscription {
    pub premium: bool,
    pub premium_until: i64,
    pub entitlements: Vec<Entitlement>,
}

/// Заказ/платёж (`GET /api/me/orders`, `GET /api/orders/{id}`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Order {
    pub id: String,
    pub plan_id: String,
    pub provider: String,
    pub method: Option<String>,
    pub status: String,
    pub currency: String,
    pub amount_rub: i64,
    pub amount_minor: Option<i64>,
    pub recurring: bool,
    pub pay_url: Option<String>,
    pub sbp_qr: Option<String>,
    pub created_at: i64,
    pub paid_at: Option<i64>,
    pub granted_at: Option<i64>,
    pub expires_at: Option<i64>,
    /// Эффективный premium-срок (только на `GET /api/orders/{id}`).
    pub premium_until: Option<i64>,
}

/// Цель открытия инвойса (CryptoBot: tg|webapp|miniapp).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PayTarget {
    pub kind: String,
    pub url: String,
}

/// Артефакт оплаты (`POST /api/checkout`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Checkout {
    pub order_id: String,
    pub provider: String,
    pub status: String,
    pub currency: String,
    pub amount_rub: i64,
    pub amount_minor: i64,
    pub recurring: bool,
    pub pay_url: Option<String>,
    pub pay_targets: Vec<PayTarget>,
    pub sbp_qr: Option<String>,
    pub expires_at: i64,
}

/// Результат активации кода (`POST /api/redeem`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Redeem {
    pub plan_id: Option<String>,
    pub period_days: Option<i64>,
    pub premium_until: Option<i64>,
}
