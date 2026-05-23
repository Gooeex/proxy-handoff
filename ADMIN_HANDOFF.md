# Admin Panel — Developer Handoff

**Artifact:** `prototype.html` (~15,100 lines, single file)
**Sibling artifact:** `../prototypes/client-panel.html` (~9,400 lines) — the client-facing surface, handed off in parallel
**Reference:** `prototypes/design-system-reference.html` (design system spec)
**Read first:** `DEV_BRIEF.md` — entry-point handoff doc covering both surfaces
**Stack target:** Railway (hosting) + Supabase (Postgres + Auth + Storage)
**Goal:** Reproduce UX/UI 1:1 in a production SPA backed by Supabase. Admin panel and client portal run on the same backend — single source of truth.

---

## Quick start

1. Open `prototype.html` in a browser (Chrome / Safari / Firefox). No build step.
2. Open `prototypes/design-system-reference.html` side-by-side. It's the canonical spec for every component, typography rule, and pattern referenced by the prototype.
3. Click through the sidebar (Dashboard / Orders / Renewals / Payments / Plans / Proxies / Clients / Audit Log / Settings) to see every page.
4. Open the JS console and run `validatePrototypeData()` to see the data-integrity invariants the system enforces.
5. Read `prototypes/design-system-reference.html` §6 for a phase-by-phase log of what shipped and why.
6. Open `../prototypes/client-panel.html` and walk through the client surface as well (demo creds: `demo@example.com` / `demo1234`).

---

## Implementation priority

Phase 1 is **not** a full enterprise admin system. The admin panel is a Super-Admin-operated internal tool; the client portal serves external users on the same backend.

Priority order:

1. Correct data model (shared by admin + client).
2. Correct order / payment / proxy lifecycle (see `LIFECYCLE_CONTRACT.md`).
3. Correct inventory assignment/release semantics (transaction-safe).
4. Correct UI reproduction (admin + client).
5. **Client authentication + strict per-client data isolation.** (Required Phase 1, not deferred.)
6. Auditability of critical actions.
7. Payment / proxy integrations.
8. Security hardening + granular admin RBAC — Phase 2 (deferred).

See `DEV_BRIEF.md` for the full two-surface scope, security policy, and Stage 1.5 markers in the client portal.

---

## What this prototype is — and isn't

### Is

- **Functional clickable spec** — every list page filters, paginates, opens a detail page; every bulk-bar action triggers a real modal; every Settings toggle persists to `db.settings`.
- **Single source of truth for UX/UI** — typography, spacing, color, table system, bulk-bar canon, form validation. `prototypes/design-system-reference.html` documents all of it.
- **Seed-data-driven** — 12 plans · 39 orders · ~31 proxies · ~50 clients · ~80 payments · ~60 logs · 14 notification rule toggles. Covers every operational edge case (exception states, dirty payments, broken proxies, renewal flows).
- **Validator-backed** — `validatePrototypeData()` enforces bidirectional invariants on every navigation. Currently reports 0 critical issues + 1 known-deferred historical marker.

### Isn't

- **Not a production frontend.** No real auth (the sidebar shows hardcoded "Alex Kovalev"), no real persistence (state lives in JS objects + localStorage for the catalog), no error boundaries, no code splitting, no accessibility audit.
- **Not a build-ready codebase.** Single 14,800-line HTML file. Will need to be sliced into components in your framework of choice (see §"Suggested framework topology" below).
- **Not security-hardened.** No XSS escaping discipline, no CSRF, no rate limiting, no role checks (everything is "Super Admin" view).

The job is to translate UX/data-model patterns into a real implementation. **Do not ship `prototype.html` or `prototypes/client-panel.html` as production frontends** — both are clickable specs, not deployable code. The same warning applies to the client-portal sandbox file `client-panel.html` (no `-v1` suffix), which is explicitly out of scope for handoff.

---

## Architecture overview

### Information architecture

```
Dashboard           — KPI strip + 4 widgets (Recent Orders, Selling Capacity, Exceptions, Issues)
Orders              — 8 tabs (All, New, Awaiting Payment, Provisioning, Active, Expired, Cancelled, Exceptions)
                      Exceptions tab has 5 sub-filters (paid-not-provisioned, renewal-not-extended, replacement-pending, etc.)
Renewals            — 6 buckets by time-to-expiry (Next 24h, In 3 days, In 7 days, In grace, Expired, Renewed)
Payments            — 7 tabs (All, Confirmed, Awaiting, Failed, Refunded, Refund requested, Manual review)
Plans               — 1 tab + status filter; capacity-state chips
Proxies             — 8 tabs (All, Attention, Assigned, Available, Faulty, Maintenance, Provisioning, Released)
Clients             — Status / Risk / Tier filters
Audit Log           — Action-type filter + actor filter + date range
Settings            — 10 sub-tabs (Providers, Notifications, Grace Rules, Admins, API/Webhooks, Display, Catalog, Provisioning, System Flags, Help)
```

Detail pages: Order detail · Plan detail (Edit) · Proxy detail · Client detail · Payment detail.

### Key design canons (read `prototypes/design-system-reference.html` for full spec)

- **Typography ramp**: 11 / 12 / 13 / 15 / 18 pt only. Mono+tabular-nums for any identifier-shaped value. (§1.2, §4.4)
- **Table system** `.dt`: proportional column widths via `--w` + `--col-total`, anchor edges via `--anchor-l` / `--anchor-r`. (§3.2)
- **Body-cell color hierarchy**: blue accent for entity links · text-secondary for primary identity · muted for reference text · chip color for status. (§4.6)
- **Bulk-bar** `.bulk-bar`: matrix-driven (per-tab × per-row-state action visibility) · Set-based selection · row-state-aware filtering on heterogeneous tabs. (§3.9)
- **Form validation**: `type="number" min max step` + `<span class="req">*</span>` markers + shared `.invalid` state + generic `validateNumericInputs()`. (§3.10)
- **Policy-override hatch**: centralized policy table + per-entity opt-in toggle. Canonical instance: Settings → Provisioning ⇄ Plan Edit. (§4.7)

---

## Tech stack notes

### Supabase

- **Auth**: use `auth.users` for admin accounts. Add a public `admins` table with foreign key to `auth.users.id` and a `role` column (`super` / `ops` / `support`). Permission matrix in §"Auth & roles" below.
- **Postgres**: schema lives in your `supabase/migrations/` directory. Suggested table structure in §"Data model" below.
- **RLS (Row-Level Security)**: every table should have policies keyed off `auth.uid()` and the role lookup. Super-only operations (manage admins, manage plans, manage webhooks) gated at the policy layer.
- **Realtime subscriptions**: useful for the Orders / Proxies / Payments list pages — operator sees state changes without manual refresh. Subscribe to `postgres_changes` on the relevant tables.
- **Storage**: not currently needed (the prototype has no file uploads). Reserved for future invoice PDFs / proxy-credentials files.
- **Edge Functions**: appropriate for webhooks (Stripe events, proxy health checks), notification dispatch (template render + email/Telegram send), and scheduled jobs (renewal sweep, faulty-proxy auto-replace).

### Railway

- Deploy your SPA (Next.js / Vite + React / Vue) as a Railway service.
- Environment variables: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (server-only, for admin functions).
- The static prototype itself never needs to ship to Railway — it's a spec, not the product.

### Suggested framework topology

- **SPA framework**: Next.js (App Router) or Vite + React. Both compose well with Supabase via `@supabase/supabase-js` + `@supabase/auth-helpers`.
- **Component model**: one component per current "page" — `<OrdersPage>`, `<OrderDetailPage>`, `<PlanEditPage>`, etc. Share `<DataTable>`, `<BulkBar>`, `<KVRow>`, `<DetailHeader>`, `<Toast>` as base primitives.
- **State**: server state via TanStack Query (or SWR); form state via React Hook Form + Zod; selection state via local `useState<Set<string>>`.
- **Styling**: CSS variables already define the entire token system. Lift the prototype's `<style>` block into a global stylesheet; component-specific styles go into CSS Modules or Tailwind. Don't rebuild the tokens — copy them.
- **Icons**: SVGs are inlined in the prototype. Consider Heroicons or Lucide for consistency.

---

## Data model — suggested Postgres schema

The prototype's `db` object (lines ~5349–5750) is the canonical reference. Below is a Postgres-friendly mapping. All `id` columns are TEXT (preserving the human-readable prefixes — `ORD-`, `PRX-`, `CLI-`, etc.); switch to UUID if you prefer, but keep the prefix as a display field.

### Settings (singleton)

```sql
create table app_settings (
  id                            int primary key default 1,
  system_auto_provision         bool not null default true,
  auto_replace_on_faulty        bool not null default true,
  auto_release_after_grace      bool not null default true,
  require_2fa_for_refund        bool not null default false,
  require_note_on_suspend       bool not null default true,
  freeze_new_orders             bool not null default false,
  notifications                 jsonb not null default '{}'::jsonb, -- 14 rule-id → bool
  grace                         jsonb not null default '{}'::jsonb, -- 3 rule-id → bool
  updated_at                    timestamptz not null default now(),
  constraint app_settings_singleton check (id = 1)
);
```

### Plans

```sql
create table plans (
  id                   text primary key,            -- 'PLAN-V30E'
  name                 text not null,
  carrier              text not null,
  region               text not null,
  pool                 text not null,
  pool_override        bool not null default false, -- Phase 2.7 hatch
  duration_days        int  not null,
  price                numeric(10,2) not null,
  available_quota      int  not null,
  allocated            int  not null default 0,
  display_available    int  not null default 0,     -- derived; consider VIEW
  active               bool not null default true,
  capacity_state       text,                        -- nullable; one of: low / sold-out / blocked-grace / waiting-release
  auto_provision       bool not null default true,
  created_at           timestamptz not null default now()
);
```

### Provisioning rules (Phase 2.7)

```sql
create table provisioning_rules (
  id              text primary key,                 -- 'PRV-001'
  carrier         text not null,
  region          text not null,
  default_pool    text not null,
  fallback_pools  text[] not null default '{}',
  auto_assign     bool not null default true,
  notes           text,
  unique (carrier, region)                          -- enforce one rule per combo
);
```

### Clients

```sql
create table clients (
  id              text primary key,                 -- 'CLI-2184'
  name            text not null,
  email           text not null unique,
  telegram        text,
  country         text,
  tier            text not null default 'standard', -- standard / pro / vip
  risk            text not null default 'none',     -- none / review / flag
  status          text not null default 'active',   -- active / suspended / blocked
  registered_at   timestamptz not null default now(),
  ltv_cents       bigint not null default 0,
  acquisition     text                              -- 'organic' / 'referral-CLI-NNNN' / 'campaign-X'
);
```

### Orders

```sql
create table orders (
  id                              text primary key,           -- 'ORD-10847'
  client_id                       text not null references clients(id),
  plan_id                         text not null references plans(id),
  qty                             int  not null default 1,
  amount                          numeric(10,2) not null,
  pay                             text not null default 'pending',  -- pending / awaiting / paid / failed
  st                              text not null default 'new',      -- new / provisioning / active / expired / cancelled / suspended / pending-renewal
  payment_id                      text references payments(id),
  proxy_id                        text references proxies(id),      -- legacy field for single-proxy orders
  auto_renew                      bool not null default true,
  auto_provision                  bool not null default true,
  created_at                      timestamptz not null default now(),
  activated_at                    timestamptz,
  expires_at                      timestamptz,
  exception                       text,                             -- paid-not-provisioned / renewal-not-extended / replacement-pending / refund-pending / etc.
  exception_info                  text,
  renewal_bucket                  text,                             -- 24h / 3d / 7d / grace / renewed
  replaces_order_id               text references orders(id),       -- pending-renewal points at parent
  renewal_grace_until             timestamptz,
  cancelled_reason                text,
  manual_provisioning             bool not null default false,
  manual_fulfillment_override     bool not null default false,
  manual_fulfillment_override_at  timestamptz,
  credentials_sent_at             timestamptz,
  credentials_channel             text,
  last_reminder                   timestamptz
);
```

### Payments

```sql
create table payments (
  id        text primary key,           -- 'PAY-8847'
  order_id  text not null references orders(id),
  provider  text not null,              -- Stripe / CoinPayments / Bank transfer / Manual
  method    text not null,              -- 'Visa •• 4242' / 'USDT' / etc.
  gross     numeric(10,2) not null,
  fees      numeric(10,2) not null default 0,
  net       numeric(10,2) not null,
  st        text not null,              -- confirmed / awaiting / failed / refunded / refund-requested / replacement / manual-review / pending
  paid_at   timestamptz not null
);
```

### Proxies

```sql
create table proxies (
  id                  text primary key,            -- 'PRX-3042'
  modem               text not null,               -- hardware id 'MDM-NN'
  imei                text not null,
  carrier             text not null,
  region              text not null,
  pool                text not null,
  ip                  inet not null,
  port                int  not null,
  status              text not null,               -- assigned / available / faulty / maintenance / provisioning / released
  health              text not null default 'healthy',  -- healthy / degraded / offline
  uptime              numeric(5,2) not null default 100,
  latency             int  not null default 0,
  current_order_id    text references orders(id),
  registered_at       timestamptz not null default now()
);
```

### Order ↔ proxy assignments (the canonical join)

```sql
create table order_proxy_assignments (
  id            text primary key,                 -- 'ASN-0847A'
  order_id      text not null references orders(id),
  proxy_id      text not null references proxies(id),
  assigned_at   timestamptz not null,
  released_at   timestamptz,                       -- NULL while active
  reason        text,                              -- release reason (e.g. 'order-expired', 'renewal-payment-timeout')
  actor         text not null default 'System'     -- admin name or 'System'
);
create index on order_proxy_assignments (order_id) where released_at is null;
create index on order_proxy_assignments (proxy_id) where released_at is null;
```

**Invariant** — when an order has `st = 'active'`, exactly one assignment row exists for it with `released_at IS NULL`. The validator `validatePrototypeData()` enforces this; production should enforce via triggers or application-layer transactions. Mirror `order.proxy_id` and `proxy.current_order_id` are denormalized for query speed, but the join table is the source of truth.

### Admins

```sql
create table admins (
  id          uuid primary key references auth.users(id) on delete cascade,
  display_id  text unique,                         -- 'adm-1' for log authorship
  name        text not null,
  role        text not null default 'support',     -- super / ops / support / bot
  status      text not null default 'active',      -- active / deactivated
  initials    text generated always as (upper(substring(name from 1 for 1) || substring(split_part(name, ' ', 2) from 1 for 1))) stored,
  ip          text,                                -- last login IP
  last_login  timestamptz
);
```

### Notification templates

```sql
create table notification_templates (
  id        text primary key,                      -- 'TPL-101'
  name      text not null,
  channel   text not null,                         -- email / telegram
  trigger   text not null,                         -- order-created / payment-confirmed / replacement-pending / etc.
  subject   text,                                  -- email only
  body      text not null,                         -- supports {{client.name}} / {{order.id}} / {{order.expires}} placeholders
  updated_at timestamptz not null default now()
);
```

### Catalog (master lists)

```sql
create table catalog_carriers (value text primary key);
create table catalog_regions (value text primary key);
create table catalog_pools (value text primary key);
create table catalog_protocols (value text primary key);
create table catalog_rotations (value text primary key);
create table catalog_traffic (value text primary key);
create table catalog_durations (value text primary key);
create table catalog_visibility (value text primary key);
create table catalog_currencies (value text primary key);
```

(Alternatively: one `catalog_items` table with `(key, value)` rows. Same query ergonomics either way.)

### Admin logs

```sql
create table admin_logs (
  id          text primary key,                    -- 'LOG-1043'
  at          timestamptz not null default now(),
  actor_id    text references admins(display_id),  -- 'adm-1' or 'adm-sys' for system
  action      text not null,                       -- 'ORDER.CANCEL' / 'PAYMENT.CONFIRM' / 'PROXY.MARK_FAULTY' / etc.
  object_type text not null,                       -- order / payment / proxy / client / plan / admin
  object_id   text not null,
  detail      text                                 -- human-readable line; identifier-shaped tokens get .mono treatment in UI
);
create index on admin_logs (at desc);
create index on admin_logs (object_type, object_id, at desc);
```

---

## Auth & roles

### Phase 1 posture (two surfaces)

- **Admin panel — Phase 1 = Super Admin only.** All initial admin users are trusted internal operators with `role = 'super'`. Granular RBAC, multi-role permission matrix, 2FA, and full RLS hardening are **deferred to Phase 2**. The schema below must still be in place (role column + `current_admin_role()` function) so Phase 2 can activate roles without a migration.
- **Client portal — Phase 1 REQUIRES client authentication and strict per-client data isolation.** External clients are untrusted. RLS policies keyed off `auth.uid()` are mandatory before client-portal go-live; a client must never see another client's orders / proxies / payments / invoices / credentials.
- **Both surfaces, always:** no secrets in frontend, backend-only payment/proxy operations, destructive actions written to audit log.

See `DEV_BRIEF.md § Security / Auth — two-surface policy` for the full posture.

### Role matrix (target — Phase 2 activation)

Three role tiers (plus `bot` for system-generated logs):

| Role          | Manages plans / pricing | Configure providers / webhooks | Manage admins | Issue refunds | Block clients | Create / modify orders |
|---------------|:---:|:---:|:---:|:---:|:---:|:---:|
| **Super**     | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Operations**| ✓ | — | — | ✓ | ✓ | ✓ |
| **Support**   | — | — | — | ✓ (<$100) | — | ✓ |

(Reference table: prototype Settings → Admins → "Role permissions". Match these row-for-row.)

### RLS pattern

```sql
create function current_admin_role() returns text language sql security definer as $$
  select role from admins where id = auth.uid();
$$;

create policy "Super-only writes on plans" on plans
  for all using (current_admin_role() = 'super');

create policy "Ops and Super write orders" on orders
  for all using (current_admin_role() in ('super', 'ops', 'support'));
```

…and so on for each table. Read access is typically open to all authenticated admins; writes are role-gated.

---

## Wired vs stub inventory

The prototype has ~40 admin flows. Most are wired end-to-end against the seed data; some are deliberate toast-stubs (placeholder for production wiring). Use this list during implementation to size the work.

### ✅ Fully wired (translate behavior 1:1)

- Orders list filtering + pagination + tab switching
- Bulk-bar actions: Send reminder · Confirm payment · Cancel · Activate · Suspend · Assign proxy · Edit · Refund (each opens a real modal with confirmAction flow + db mutation)
- Order detail page: every kv-row, activity widget, assignment history, lifecycle, exception banner
- Payment detail page: full kv layout, related-order link
- Plan Edit: every form field bound to plan record, Save + Delete flows, capacity readout computed live, "Override default pool" toggle (Phase 2.7)
- Proxy Detail: Force replace, Rotate IP, Mark faulty, Release, Add note (Force replace + Mark faulty open real modals)
- Client Detail: every panel (Profile, Orders, Payments, Activity, Risk review)
- Settings → Notifications: 14 toggles wired to `db.settings.notifications` + template CRUD
- Settings → Grace Rules: 3 toggles + 7 numeric inputs, Save runs validateNumericInputs() with monotonicity
- Settings → Admins: live admin count, Reactivate confirmAction flow
- Settings → System Flags: 6 toggles wired (Auto-provision, Auto-replace, Auto-release, Freeze) + 4 numeric inputs with validation
- Settings → Catalog: full CRUD on 9 master lists, localStorage-persisted
- Settings → Provisioning (Phase 2.7): add / edit / list provisioning rules · duplicate-guard on (carrier, region)
- Validator: `validatePrototypeData()` flags bidirectional drift, ghost references, lifecycle invariants, dirty payments

### 🟡 Stub-only (toast on click; needs production wiring)

- Settings → Providers: Connect PayPal · Copy/Rotate API keys (Stripe webhook secret)
- Settings → API / Webhooks: Add webhook · Edit webhook · Test webhook · View deliveries (table is static markup — see "deferred work" below)
- Settings → Admins: Invite admin · Edit admin role (Maria's row has toast stub; Dana's row has no handler)
- Settings → Help: Workflow diagrams (only 1 of ~6 written; `flow.html` exists alongside)
- Order Detail: Rotate IP · Health check (proxy detail page) — toast only
- Reset buttons in Settings sections — visual only

### 🔴 Deferred — needs design + implementation pass

- **Webhook management section** — full feature, postponed during prototype phase. Will need: `db.webhooks` table, list renderer, Add/Edit modal, Test webhook (sends a synthetic event), View deliveries (recent activity log with retry status), event picker (multi-select against the available event types).

---

## Form validation contracts

All numeric inputs carry `type="number" min="X" max="Y" step="S"`. Reproduce these bounds server-side (Zod schemas on form input; Postgres CHECK constraints as a safety net).

| Field                                | Min | Max   | Step |
|--------------------------------------|----:|------:|-----:|
| Price (plan)                         |   1 | 99999 | 0.01 |
| Available quota                      |   1 |  9999 |    1 |
| Low-capacity threshold (%)           |   0 |   100 |    1 |
| Renewal discount (%)                 |   0 |   100 |    1 |
| Pre-renewal reminder hours (plan)    |   0 |   720 |    1 |
| Grace period hours (plan)            |   0 |   720 |    1 |
| Default grace period (Settings)      |   0 |   720 |    1 |
| Pre-renewal reminder (Settings)      |   0 |   720 |    1 |
| Second reminder hours                |   0 |   168 |    1 |
| Third reminder hours                 |   0 |   168 |    1 |
| VIP / Pro / Standard grace hours     |   0 |   720 |    1 |
| Public API rate limit (req/min)      |   1 |  9999 |    1 |
| Max concurrent orders / client       |   1 |   999 |    1 |
| Max proxy replacements / order       |   1 |    10 |    1 |
| Support refund cap (USD)             |   0 | 99999 |    1 |
| Discount cap (%)                     |   0 |   100 |    1 |
| USDT confirmations required          |   1 |    99 |    1 |
| Order quantity                       |   1 |    20 |    1 |
| Order discount (%)                   |   0 |   100 |    1 |

### Domain-rule validators

- **Grace Rules monotonicity**: Second reminder < Pre-renewal reminder; Third < Second. Validate on Save.
- **Provisioning rule uniqueness**: (carrier, region) unique. Duplicate submit toasts "Rule already exists — edit that row instead."
- **Order ↔ proxy carrier/region alignment**: a proxy assigned to an order must match the order's plan carrier + region. Enforce on assignment transaction.
- **Order lifecycle transitions**: see `prototype.html` validator function for the full state-machine (active orders need credentials_sent_at, suspended orders keep assignments, cancelled orders release them, etc.).

---

## Edge cases & operator scenarios to test

The seed data is engineered to exercise every edge case. Reproduce these scenarios in your QA:

1. **Pending-renewal flow with timeout** — `sweepPendingRenewals()` auto-cancels stale pending-renewal orders past `renewal_grace_until`. Two orders in seed (ORD-10920, ORD-10921) demonstrate the cleanup path.
2. **Replacement payment with active order** — ORD-10638 has `exception: 'renewal-not-extended'`, ORD-10838 has `exception: 'refund-pending'` with a `replacement`-state payment. Both surface the operator-reconciliation banner.
3. **Faulty proxy with replacement-pending exception** — ORD-10810 / 10813 / 10817 cover three replacement-pending sub-states (proxy still bound · proxy already released · auto-replace failed).
4. **Paid-not-provisioned exception** — ORD-10915 demonstrates "payment confirmed but pool exhausted, stuck 14h."
5. **Suspended order resume** — Plans Edit shows "Active" status flips when toggling plan.active; Order Detail shows resume affordance preserves the proxy.
6. **Renewal cascade** — ORD-10847 has been renewed into ORD-10920 (qty-up scenario). Both orders coexist with proper proxy carryover semantics. See `getDerivedCapacity()` in the prototype for the qty-delta math.
7. **Tab heterogeneity in bulk-bar** — Orders / All tab + multi-select rows of mixed status → `computeOrdersLabels()` intersects per-status action sets so only ALL-valid actions appear.
8. **Selection survives re-render** — Select 3 rows on Orders, change search query → matched rows keep their `.checked` state because `ORDERS_SELECTED` Set is the source of truth.
9. **Empty-state coverage** — Apply filters that match nothing on every list page. Empty-state markup includes a contextual message + Reset filters action.

---

## Required before implementation: lifecycle contract

Before building backend mutations, extract and approve a formal state machine for:

- Order
- Payment
- Proxy
- Assignment
- Renewal
- Replacement
- Refund

The prototypes contain representative states and flows, but production implementation must encode valid transitions explicitly. The contract must also define **which transitions a client may initiate vs admin-only** (renewals are client-initiable as direct executions; replacements and refunds are client-initiable as requests → admin processes).

A working draft lives in `LIFECYCLE_CONTRACT.md` alongside this file. Fill in and sign off before writing mutation code.

---

## Open production decisions

Things the prototype doesn't decide for you — flag during implementation:

1. **Payment provider integration** — Stripe is the canonical card processor (referenced everywhere), CoinPayments for USDT/USDC/BTC, manual bank-transfer. Wire each via webhook → Edge Function → DB mutation. Refund flow needs Stripe Refund API call + state sync.
2. **Notification dispatch** — templates exist as records; production needs a queue worker (Supabase Edge Function on a cron) that picks up `payment.confirmed`, `order.activate`, `replacement-pending` etc. events and renders the template against `client` / `order` / `proxy` context. Email via SendGrid/Resend; Telegram via bot API.
3. **Proxy hardware integration** — the prototype assumes proxies expose `ip / port / modem` and report `health / uptime / latency`. Production needs an integration layer (per-vendor adapter) that polls or receives health events.
4. **Webhook outbound** — Settings → API / Webhooks lists three example endpoints. Production needs event types, signing secret rotation, retry queue with exponential backoff, delivery history table. (Deferred during prototype phase.)
5. **Activity log retention** — `admin_logs` grows unboundedly. Pick a retention policy (90d? 1y? archive to S3?).
6. **Realtime vs polling** — for the operator view, realtime via Supabase channels gives the best UX. But it's optional — TanStack Query refetchInterval works fine for v1.
7. **Test webhook flow** — see "deferred work" above. Needs Edge Function that emits a sample payload (per event type) to the configured endpoint.

---

## What's not covered

- **Client-facing portal** — handed off **in parallel** with this admin panel. Lives at `../prototypes/client-panel.html` and shares the same backend / database. See `DEV_BRIEF.md` for the full two-surface scope. (The sibling file `client-panel.html` without the `-v1` suffix is a sandbox kept for future exploration — **not** part of the handoff.)
- **Marketing site / landing pages** — N/A for this prototype.
- **Mobile responsiveness** — the prototype is desktop-only (admin tool). Production should clamp to a minimum width (probably 1280px) and degrade gracefully below; tablet/phone are explicit non-targets.
- **Internationalization** — all UI is English. If multilang is needed, the prototype labels are easy to extract into a JSON dictionary; no string concatenation in templates that would block i18n.

---

## Reference files

- `prototype.html` — single-file HTML prototype with full seed data + all flows
- `prototypes/design-system-reference.html` — design system spec, ramp/spacing/colors/components/patterns/migration log
- `icon-kits.html` — visual reference for icon styles considered during design phase (optional)

Run `validatePrototypeData()` in the prototype's JS console any time to confirm seed integrity. Currently passes with 0 critical issues.

---

**Document version:** 1.0 · 2026-05-19 · Phase 2.7 freeze
