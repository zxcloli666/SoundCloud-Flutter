//! Мапперы платёжных доменных моделей в плоские FRB-DTO.

use sc_domain::{Checkout, Entitlement, Order, Plan, Redeem, Subscription};

use crate::dto_pay::{
    CheckoutDto, EntitlementDto, OrderDto, PayTargetDto, PlanDto, RedeemDto, SubscriptionDto,
};

pub(crate) fn plan(p: Plan) -> PlanDto {
    PlanDto {
        id: p.id,
        months: p.months,
        period_days: p.period_days,
        price_rub: p.price_rub,
        savings_pct: p.savings_pct,
        stars: p.stars,
    }
}

fn entitlement(e: Entitlement) -> EntitlementDto {
    EntitlementDto {
        source: e.source,
        starts_at: e.starts_at,
        ends_at: e.ends_at,
        recurring: e.recurring,
        auto_renew: e.auto_renew,
        canceled: e.canceled,
    }
}

pub(crate) fn subscription(s: Subscription) -> SubscriptionDto {
    SubscriptionDto {
        premium: s.premium,
        premium_until: s.premium_until,
        entitlements: s.entitlements.into_iter().map(entitlement).collect(),
    }
}

pub(crate) fn order(o: Order) -> OrderDto {
    OrderDto {
        id: o.id,
        plan_id: o.plan_id,
        provider: o.provider,
        method: o.method,
        status: o.status,
        currency: o.currency,
        amount_rub: o.amount_rub,
        amount_minor: o.amount_minor,
        recurring: o.recurring,
        pay_url: o.pay_url,
        sbp_qr: o.sbp_qr,
        created_at: o.created_at,
        paid_at: o.paid_at,
        granted_at: o.granted_at,
        expires_at: o.expires_at,
        premium_until: o.premium_until,
    }
}

pub(crate) fn checkout(c: Checkout) -> CheckoutDto {
    CheckoutDto {
        order_id: c.order_id,
        provider: c.provider,
        status: c.status,
        currency: c.currency,
        amount_rub: c.amount_rub,
        amount_minor: c.amount_minor,
        recurring: c.recurring,
        pay_url: c.pay_url,
        pay_targets: c
            .pay_targets
            .into_iter()
            .map(|t| PayTargetDto {
                kind: t.kind,
                url: t.url,
            })
            .collect(),
        sbp_qr: c.sbp_qr,
        expires_at: c.expires_at,
    }
}

pub(crate) fn redeem(r: Redeem) -> RedeemDto {
    RedeemDto {
        plan_id: r.plan_id,
        period_days: r.period_days,
        premium_until: r.premium_until,
    }
}
