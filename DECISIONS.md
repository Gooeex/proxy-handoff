# Product Decisions — Stage 1.5 handoff

Decisions taken on 2026-05-23 by the product owner while reviewing the Client Portal v1 ↔ Admin Panel handoff. Each entry below is **"decided / not up for debate"**. Use these when wiring up backend in the next phase.

## Canonical files

- **Client portal prototype:** `prototypes/client-panel.html`
- **Admin panel prototype:** `prototypes/admin-panel.html`
- **Design system reference:** `prototypes/design-system-reference.html`

## Stage 1.5 UI markers
A `.stage15-badge` / `.stage15-note` CSS primitive lives in `prototypes/client-panel.html`. Use it to surface any UI element whose backend isn't wired up yet. **Form: `<span class="stage15-badge" title="…detailed reason…">v1.5</span>`** placed inline next to a panel title / column header / kv-label. Currently applied to:
- Account balance (Billing page)
- Transactions → Invoice column (Billing page panel-header)
- Whitelist panel (Proxy Detail)
- Rotation URL panel (Proxy Detail)
- Auto rotation kv-row (Proxy Detail Info aside)

When adding new Stage 1.5 features, follow the same convention so the dev can find all gaps with a single grep.

## Decisions

### 1. Account balance / ledger — Stage 1.5

**Storage model:** per-client append-only ledger.
- Table `client_balance_ledger`: `id`, `client_id`, `op_type` ('topup' | 'order_debit' | 'refund_credit' | 'manual_adjust'), `amount` (signed), `currency`, `payment_id` (FK nullable), `order_id` (FK nullable), `note`, `actor_type` ('client' | 'admin' | 'system'), `actor_id`, `created_at`.
- Current balance = `SUM(amount) WHERE client_id = X` — never stored as a snapshot.

**UI surfaces:**
- **Client portal (v1):** topbar `$N / Add funds`, Billing → Account balance card, Transactions tab (ledger entries already shown intermixed with payments — backend will keep this pattern).
- **Admin (Stage 1.5):** in Client Detail aside, new panel **Balance** with current balance + `+ Adjust` button. Adjust modal: signed `amount`, required `reason`, optional `note` → creates ledger row with `op_type='manual_adjust'`, `actor=admin`. Below the value, last 10 ops + `View all` → dedicated `Client → Balance ledger` screen.
- **Admin global aggregation (Phase 2+):** `Reports → Balances` with total liabilities, top-balance clients, recent manual adjusts. NOT needed for MVP — add when finance reporting comes online.

**Flows:**
- Top-up confirms → `+amount, op_type=topup`.
- Order purchase with balance → `-amount, op_type=order_debit`.
- Refund issued → `+amount, op_type=refund_credit`.
- Admin adjust → `±amount, op_type=manual_adjust, note required`.

### 2. Invoice entity — Stage 1.5

**Architecture:** Invoice is its own entity, **NOT a column on Payments**. Payment = transaction; Invoice = fiscal doc.

**Schema:**
- Table `invoices`: `id` (e.g. `INV-YYYY-NNNNN`, reset yearly, atomic sequence), `payment_id` (UNIQUE FK), `order_id` (FK nullable — top-ups have no order), `client_id`, `amount`, `currency`, `issued_at`, `pdf_url`, `tax_amount` (nullable until tax model lands), `billing_address_snapshot` (JSON).
- 1:1 with confirmed payments. No invoice for awaiting/failed/refunded. Refunds create credit_note (Phase 2 entity).

**Where it surfaces:**
| Place | What to show |
|---|---|
| Client → Billing → Transactions | "Invoice" column with `Download` link (already in v1) |
| Client → Billing → Invoices tab (NEW) | Full list with year/status filters — add in Stage 1.5 |
| Client → Order Detail | In Order snapshot: `Invoice: INV-XXXXX [Download]` next to Payment field |
| Admin → Payment Detail | Invoice link + Download PDF |
| Admin → Client Detail | aside panel "Recent invoices" (top 5) + View all |

**PDF generation:** backend job triggered on payment confirm. Client mock currently opens HTML preview; backend produces PDF.

### 3. Whitelist (per proxy IP allowlist) — Stage 1.5

**Backend:**
- Table `proxy_whitelist`: `id`, `proxy_id` (FK), `ip_cidr` (text, validated IPv4/IPv6 single or /CIDR), `label` (user comment, opt), `added_by` ('client'|'admin'), `added_by_id`, `added_at`, `last_used_at` (gateway updates).
- Cap: **5 entries per proxy** (hard limit, enforced at API; client UI already knows).
- API: `GET /proxies/:id/whitelist`, `POST`, `DELETE /:entry_id`.

**Edge enforcement (CRITICAL):**
- Proxy gateway checks `source_ip ∈ whitelist(proxy_id)` before forwarding.
- Empty whitelist → allow all (current mock behavior).
- Non-empty whitelist → reject non-matching with HTTP 403 at gateway level.

**Admin UI:**
- In Proxy Detail (admin) add **Whitelist** panel: read-only list + `Force clear all` for emergency unblock.
- Logs: new audit event types `PROXY.WHITELIST.ADD`, `PROXY.WHITELIST.REMOVE` with actor.

**Client UI:** already present at `/proxies/:id`, marked with Stage 1.5 badge.

### 4. Plan price — Plans driven ✅ (no action)

- Price always lives on `plan.price`.
- Order create snapshots: `amount = plan.price * qty` (so admin price edits don't break historical orders).
- Catalog/checkout shows live `plan.price`; order history shows `order.amount` (snapshot).
- Admin price edits affect new orders only.

### 5. Status field naming → `status` ✅

- API contract uses `status` (not `st`).
- Admin DB can keep `st` or migrate — backend API layer translates either way.
- Client already on `status`.

### 6. Plan naming — Ready-made client display name ✅

- Plan record carries **two fields**:
  - `internal_name` (admin-facing): `"Verizon 30d East"`
  - `display_name` (client-facing): `"30-day Mobile · East"`
- API: admin endpoints return `internal_name`; client endpoints return `display_name`.
- Admin Plan Create/Edit form: add **Display name** field with placeholder/auto-fill from template `${durationDays}-day Mobile · ${region.replace('US ', '')}`. Empty value → backend auto-generates from template.

### 7. Rotation policy — Stage 1.5 (requires product input)

**Currently broken:** admin has rotation policy enum (Sticky/Auto/URL/All three) in Catalog list but it's not connected to the plan form, and client per-proxy `autoRotateMin` lives in its own minute-interval world.

**Proposed model (needs PO sign-off before backend impl):**
1. **Plan describes allowed options** (admin-controlled):
   - `rotation_policies_allowed: Array<'sticky'|'auto'|'url'>` — multi-select.
   - `auto_interval_min_choices: number[]` — e.g. `[5,15,30,60]` for premium, `[60,240]` for basic.
2. **Client per-proxy picks within allowed set:**
   - `'auto' ∈ allowed` → show interval selector with `auto_interval_min_choices`.
   - `'auto' ∉ allowed` → hide auto-rotation UI entirely.
   - `'url' ∈ allowed` → show Rotation URL panel + Reset URL.
   - `'url' ∉ allowed` → hide Rotation URL panel.
   - "Sticky" = default when both auto and url are off.
3. **Backend validates** PATCH /proxies/:id: `autoRotateMin ∈ plan.auto_interval_min_choices`; URL reset allowed only if `'url' ∈ plan.rotation_policies_allowed`.

**Open questions for PO:**
- Default policies per duration (7d/30d/90d).
- Can admin override per-proxy (currently NO — all plan-driven).

### 8. Provider names — Stage 1.5

- Internal field (DB): `provider_id` enum: `'stripe' | 'coinpayments' | 'bank_transfer' | 'paypal'`.
- Client display (API maps internal → friendly): Card / Crypto / Bank transfer / PayPal.
- Admin display: internal id + custom alias.
- `payment.method` stays free-form (`"Visa •• 4242"`, `"USDT (TRC20)"`, `"Apple Pay"`) — both sides show it alongside provider name.

### 9. Credentials delivery — Send-event is delivery ✅

- `credentials_sent_at` (timestamp): when backend initiated email/Telegram send. THIS is delivery.
- `credentials_channel`: `'email' | 'telegram' | 'both' | null`.
- `credentials_delivery_status`: `'queued' | 'sent' | 'failed' | 'bounced'` — for admin troubleshooting.
- Portal view does NOT count as delivery. Backend logs `PROXY.CREDENTIALS_VIEWED` for audit only.
- If `credentials_sent_at = null` AND user is on Order/Proxy Detail: show client-portal banner "Credentials available in portal — email delivery pending".

## How to verify decisions are honored when wiring backend

- `grep "stage15-badge"` in `prototypes/client-panel.html` → enumerate every UI element awaiting backend.
- Each badge's `title=` attribute carries the spec sentence — backend dev reads it to know what to build.
- Don't remove markers until the corresponding endpoint ships + integration test passes.

---

See also: `DEV_BRIEF.md` (entry point), `ADMIN_HANDOFF.md` (admin-side data model + lifecycle), `LIFECYCLE_CONTRACT.md` (state machines), `ROADMAP.md` (v1 / v1.5 / v2 split).
