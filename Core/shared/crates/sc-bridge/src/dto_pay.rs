//! Плоские FRB-DTO платёжного слоя STAR. Мапперы — в [`crate::map_pay`].

#[derive(Clone, Debug)]
pub struct PlanDto {
    pub id: String,
    pub months: i64,
    pub period_days: i64,
    pub price_rub: i64,
    pub savings_pct: i64,
    pub stars: i64,
}

#[derive(Clone, Debug)]
pub struct EntitlementDto {
    pub source: String,
    pub starts_at: i64,
    pub ends_at: i64,
    pub recurring: bool,
    pub auto_renew: bool,
    pub canceled: bool,
}

#[derive(Clone, Debug)]
pub struct SubscriptionDto {
    pub premium: bool,
    pub premium_until: i64,
    pub entitlements: Vec<EntitlementDto>,
}

#[derive(Clone, Debug)]
pub struct OrderDto {
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
    pub premium_until: Option<i64>,
}

#[derive(Clone, Debug)]
pub struct PayTargetDto {
    pub kind: String,
    pub url: String,
}

#[derive(Clone, Debug)]
pub struct CheckoutDto {
    pub order_id: String,
    pub provider: String,
    pub status: String,
    pub currency: String,
    pub amount_rub: i64,
    pub amount_minor: i64,
    pub recurring: bool,
    pub pay_url: Option<String>,
    pub pay_targets: Vec<PayTargetDto>,
    pub sbp_qr: Option<String>,
    pub expires_at: i64,
}

#[derive(Clone, Debug)]
pub struct RedeemDto {
    pub plan_id: Option<String>,
    pub period_days: Option<i64>,
    pub premium_until: Option<i64>,
}
