# Lifecycle Contract TODO

## Purpose

This file tracks the formal state machine that **must be extracted and signed off before backend mutations are implemented**. The contract is shared by both admin and client surfaces — the same database state drives both.

The prototypes encode this state machine implicitly through seed data and renderer logic. Production must encode it explicitly, in code and (where possible) in database constraints / triggers.

**Status:** 📋 draft — fill in and sign off before writing mutation code.

## Entities under contract

- **Order**
- **Payment**
- **Proxy**
- **Assignment** (Order ↔ Proxy join — `order_proxy_assignments`)
- **Renewal**
- **Replacement**
- **Refund**

> Note on dual-field model in `orders`: the prototype's `orders.st` (lifecycle) and `orders.pay` (payment status) are independent. Decide in Phase 1 whether production keeps two fields or collapses to one. The contract below treats them as independent for now.

---

## Required tables — fill in before backend work

### Order states (`orders.st`)

| State | Meaning | Entry condition | Exit condition | Blocking questions |
|---|---|---|---|---|
| `new` | Created, payment not yet confirmed | Order create | Payment confirmed → `provisioning`; payment fails → may stay `new` (operator retry) or transition to `cancelled` | Dual-field with `orders.pay`: keep or collapse? |
| `provisioning` | Paid, assigning proxy | `pay='paid'` AND `auto_provision=true` | Assignment created → `active`; pool exhausted → stays `provisioning` with `exception='paid-not-provisioned'` | What's the timeout before raising the exception? |
| `active` | Live service, proxy assigned, credentials sent | Assignment row created + `credentials_sent_at` set | Renewal / expiry / cancel / suspend / replacement-pending | |
| `pending-renewal` | Renewal order created; original still `active` | New order with `replaces_order_id` set | Renewal payment confirmed → extend original; timeout → cancel renewal, leave original to expire | Does pending-renewal reserve capacity? Prototype: yes (`allocated` reflects it) |
| `expired` | Past `expires_at`, in grace | Cron sweep finds past-expiry | Renewed → back to `active`; grace passes → `cancelled` and proxy released | Per-plan grace vs per-client-tier grace — which wins? |
| `suspended` | Admin paused service | Admin action | Admin resume → `active`; admin cancel → `cancelled` | Does suspend release the proxy? **Prototype: NO** (preserved) |
| `cancelled` | Terminal | Admin cancel OR renewal cleanup OR grace passed | — | |

### Payment states (`payments.st`)

| State | Meaning | Entry condition | Exit condition | Blocking questions |
|---|---|---|---|---|
| `pending` | Order created, gateway not yet hit | Order create | Gateway callback | |
| `awaiting` | Sent to gateway, waiting confirmation | Gateway "needs confirmation" callback | Gateway success / fail | USDT confirmations: configurable per-plan? Currently global Settings |
| `confirmed` | Funds received | Gateway success | Refund / replacement | |
| `failed` | Gateway rejected | Gateway fail | Operator may retry → new payment row | |
| `refunded` | Funds returned | Admin refund + gateway confirm | — | Partial refunds supported? Prototype: implied no |
| `refund-requested` | Refund initiated, not yet executed | Client/admin request | Gateway confirm → `refunded` | Who can initiate: client / admin / both? |
| `replacement` | Used to settle a replacement-pending exception | Admin marks payment as covering replacement | — | |
| `manual-review` | Suspicious / flagged | Risk engine OR admin flag | Admin clear → previous state; admin reject → `failed` | |

### Proxy states (`proxies.status`)

| State | Meaning | Entry condition | Exit condition | Blocking questions |
|---|---|---|---|---|
| `assigned` | In active service for an order | Assignment row (`released_at IS NULL`) | Assignment closed | Can same proxy be assigned to >1 order? Sequentially: yes. Concurrently: **NO**. Enforce via partial unique index. |
| `available` | In pool, ready to assign | Released from previous order OR provisioned fresh | Assignment created | |
| `provisioning` | New unit being onboarded | Admin adds proxy | Health check passes → `available` | |
| `faulty` | Health checks failing | Health probe / admin mark | Admin clear → `available`; admin replace → `released` | Auto-replace threshold: configurable in Settings |
| `maintenance` | Admin paused for upkeep | Admin action | Admin resume → previous | Does maintenance release the order's assignment? **Prototype: NO** |
| `released` | Returned to pool from previous assignment | Order ended (expired/cancelled/replaced) | Auto-reassigned → `assigned`; retired → out of pool | |

### Assignment states (`order_proxy_assignments`)

| State | Meaning | Entry condition | Exit condition | Blocking questions |
|---|---|---|---|---|
| `active` (`released_at IS NULL`) | Order ↔ proxy bound | Order activate | Order lifecycle end / replacement | |
| `closed` (`released_at` set) | Assignment terminated | Lifecycle event | — | `reason` field values: `order-expired`, `renewal-payment-timeout`, `replacement-requested`, `admin-release`, `proxy-faulty-replaced`, `order-cancelled` — exhaustive list? |

---

## Required transition table — fill in

Draft below is extracted from prototype seed/lifecycle. Confirm against `prototype.html`'s `validatePrototypeData()` invariants and any operator scenarios in `HANDOFF.md § Edge cases` before sign-off.

| Entity | From | Event | To | Side effects | Must audit? | Initiator | Blocking questions |
|---|---|---|---|---|---|---|---|
| Order | `new` | `payment.confirmed` | `provisioning` | Trigger assignment search | yes | system | |
| Order | `provisioning` | `assignment.created` | `active` | Set `credentials_sent_at`, send notification, mark `credentials_channel` | yes | system | |
| Order | `provisioning` | `pool_exhausted` (timeout) | `provisioning` (exception: `paid-not-provisioned`) | Raise exception flag; notify ops | yes | system | What's the timeout? |
| Order | `active` | `client.renew` or `system.auto_renew` | `pending-renewal` (new order) | Original stays `active`; new order created with `replaces_order_id` | yes | client or system | |
| Order | `pending-renewal` | `payment.confirmed` | (consume) | Extend original `expires_at` by renewal duration; close pending-renewal order | yes | system | |
| Order | `pending-renewal` | `timeout` (grace passed) | `cancelled` | Original order proceeds to `expired` per schedule | yes | system | |
| Order | `active` | `admin.suspend` | `suspended` | Preserve assignment | yes | admin | |
| Order | `suspended` | `admin.resume` | `active` | — | yes | admin | |
| Order | `active` | `admin.cancel` | `cancelled` | Release assignment | yes | admin | |
| Order | `active` | `expiry_passed` | `expired` | Enter grace; assignment preserved | yes | system | |
| Order | `expired` | `grace_passed` AND `auto_release_after_grace=true` | `cancelled` | Release assignment | yes | system | |
| Order | `active` | `client.replacement_request` | `active` (exception: `replacement-pending`) | Notify admin | yes | client (request) | |
| Order | `active` (excl. pending) | `client.refund_request` | `active` (exception: `refund-pending`) | Notify admin | yes | client (request) | Is refund allowed after assignment? Prototype: yes |
| Payment | `pending` | `gateway.confirm` | `confirmed` | Trigger order provisioning | yes | system | |
| Payment | `confirmed` | `admin.refund` | `refund-requested` | — | yes | admin | |
| Payment | `refund-requested` | `gateway.refund_confirm` | `refunded` | Restore client balance ledger (Stage 1.5) | yes | system | |
| Proxy | `available` | `assignment.create` | `assigned` | Set `current_order_id`; emit `PROXY.ASSIGN` log | yes | system | |
| Proxy | `assigned` | `assignment.close` | `available` OR `released` | Clear `current_order_id`; emit `PROXY.RELEASE` log | yes | system / admin | Difference between `available` and `released`? Prototype: `released` is a transient state before re-pool; `available` is permanent |
| Proxy | `assigned` | `health.fail` | `faulty` | Raise `replacement-pending` exception on bound order | yes | system | |
| Proxy | `faulty` | `admin.replace` | `released` | New proxy assigned to bound order | yes | admin | |
| Proxy | `*` | `admin.maintenance_on` | `maintenance` | Preserve assignment | yes | admin | |
| Assignment | (none) | `order.activate` | `active` | — | yes | system | |
| Assignment | `active` | `order.cancel` | `closed` | `reason='order-cancelled'` | yes | admin | |
| Assignment | `active` | `order.expire` AND grace passed | `closed` | `reason='order-expired'` | yes | system | |
| Assignment | `active` | `proxy.faulty` AND `admin.force_replace` | `closed` | `reason='replacement-requested'`; new assignment created | yes | admin | |

---

## Must-resolve before backend implementation

- [ ] **Can a paid order exist without proxy assignment?** Yes — `provisioning` state, or `paid-not-provisioned` exception. Confirm exit conditions and timeout values.
- [ ] **Can an active order exist with payment not confirmed?** Per prototype: no. Validator enforces. Production: lock via DB trigger.
- [ ] **Can a proxy be assigned to more than one active order concurrently?** No. Enforce via partial unique index `WHERE released_at IS NULL`.
- [ ] **What exactly releases a proxy?** Order end (expire/cancel/replace) + admin manual release + proxy retired. Enumerate the full event list.
- [ ] **Is release automatic after grace or manual?** Per Settings `auto_release_after_grace` flag.
- [ ] **Does replacement preserve credentials or generate new ones?** **Needs PO decision.** Default proposal: generate new credentials, send via configured channel.
- [ ] **When does renewal extend service?** On payment confirm of pending-renewal order. Original `expires_at += renewal duration`.
- [ ] **Is refund allowed after proxy assignment?** Yes per prototype seed; needs side-effect spec (does refund release the proxy? release the assignment? leave order `active`?).
- [ ] **What happens to capacity during pending renewal?** Currently: plan `allocated` reserves the seat. Confirm.
- [ ] **Which lifecycle transitions can a client initiate vs admin-only?**
  - Renewal: client-initiated (auto-renew toggle or one-shot).
  - Replacement: client request → admin executes.
  - Refund: client request → admin approves.
  - Cancel: client cannot self-serve in MVP — admin-only.
- [ ] **Is renewal/replacement client-initiated as a request, or executed directly?**
  - Renewal → executed directly (system creates pending-renewal order).
  - Replacement / refund → request pending admin action.
- [ ] **What proxy credentials are visible to the client, and at which states?** Visible when order is `active`. Per Stage 1.5 decision (memory: `decisions_stage15_handoff.md` § 9): `credentials_sent_at` marks "delivery"; portal view is audit-only (`PROXY.CREDENTIALS_VIEWED`).

---

## Sign-off checklist

Before backend mutation code begins:

- [ ] All "Blocking questions" answered or explicitly deferred to Phase 1.5/2.
- [ ] Transition table is exhaustive (no implied transitions).
- [ ] Each transition's audit requirement is decided.
- [ ] Each transition's initiator is decided (`client` / `admin` / `system`).
- [ ] Race conditions identified for each system-initiated transition (esp. proxy assignment).
- [ ] Production-equivalent of `validatePrototypeData()` is written and runs as a CI check.

---

## References

- `HANDOFF.md § Data model` — table schemas
- `HANDOFF.md § Edge cases & operator scenarios` — exercise scenarios for QA
- `prototype.html` — `validatePrototypeData()` function for invariant enumeration
- `prototypes/client-panel.html` — client-side state machine assumptions (read-only on client; mutations go via backend)
- Session memory `decisions_stage15_handoff.md` — Stage 1.5 product decisions (balance ledger, invoice, whitelist, rotation, providers, credentials delivery)
