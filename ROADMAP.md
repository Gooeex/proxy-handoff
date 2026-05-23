# Roadmap

Three rings of scope, in order of when they ship. Use this to decide what goes in MVP vs what's parked.

---

## v1 — MVP

Frontend prototype is **complete**. Backend implementation phase.

### Client portal (`prototypes/client-panel.html`)

| Surface | State |
|---|---|
| Auth — login / register / forgot / reset | Frontend ready |
| Dashboard — KPIs (Active orders, Total proxies, Open tickets), Recent orders, Expiring soon, Recent activity, Buy-more CTA | Frontend ready |
| Proxies list + per-proxy detail | Frontend ready |
| Orders list + per-order detail (Snapshot / Activity / Proxies / Lifecycle) | Frontend ready |
| Catalog + Checkout (multi-step: details → payment → processing → success/failed) | Frontend ready |
| Deposit / top-up flow (reuses checkout shell) | Frontend ready |
| Billing — Transactions, Payment methods, Account balance card | Frontend ready (balance card has v1.5 marker — backend pending) |
| Settings — Profile, Security, Notifications | Frontend ready |

### Admin panel (`prototypes/admin-panel.html`)

| Surface | State |
|---|---|
| Dashboard, Orders, Renewals, Payments, Plans, Proxies, Clients, Audit Log, Settings | Frontend ready |
| All Phase 1 admin features per `ADMIN_HANDOFF.md` | Frontend ready |

### v1 backend work

See `IMPLEMENTATION_BACKLOG.md` for the phased breakdown. Highlights:

1. Database schema (Supabase Postgres + RLS)
2. Auth (Supabase Auth — email/password, magic-link optional)
3. Order / Payment / Proxy lifecycle state machines (`LIFECYCLE_CONTRACT.md`)
4. Proxy inventory + assignment
5. Plans + catalog + capacity
6. Webhook integration (Stripe / CoinPayments) — may slip to v1.5
7. Per-vendor proxy provisioning adapters — may slip to v1.5

---

## v1.5 — Stage 1.5 backend gaps

Surfaces marked in the client portal with the `.stage15-badge` "v1.5" amber pill. UI is ready; backend contract is documented in `DECISIONS.md`. Implementation order is driven by customer demand — none of these block v1 launch, but all five should land within a small number of weeks after v1.

| # | Surface | Backend needed | Spec |
|---|---|---|---|
| 1 | Billing → Account balance card | `client_balance_ledger` (append-only, 4 op_types) | `DECISIONS.md` §1 |
| 2 | Billing → Transactions → Invoice column + Invoices tab | `invoices` entity (1:1 confirmed payment, PDF on confirm) | `DECISIONS.md` §2 |
| 3 | Proxy Detail → Whitelist panel | `proxy_whitelist` (cap 5/proxy) + edge enforcement at gateway | `DECISIONS.md` §3 |
| 4 | Proxy Detail → Rotation URL panel | Plan-level `rotation_policies_allowed` field | `DECISIONS.md` §7 |
| 5 | Proxy Detail → Auto rotation kv-row | Plan-level `auto_interval_min_choices` field | `DECISIONS.md` §7 |

Verification: `grep -n "stage15-badge" prototypes/client-panel.html` enumerates every surface awaiting backend.

---

## v2 — Deferred

Features that have been intentionally **excluded from v1 and v1.5**. Most have no UI in the canonical prototype yet — they were prototyped earlier, validated as useful, and parked until the platform fundamentals are stable.

### Client portal — v2 features

| Feature | Why deferred |
|---|---|
| **Support tickets** | Requires admin-side queue / SLA / agent-routing UI before a client-facing inbox makes sense. v1 support runs via Telegram (linked from the empty-state CTAs). |
| **API tokens + endpoint reference** | Token issuance + scoping + audit requires admin tooling that doesn't exist in Phase 1. Customers asking for API access in v1 are handled via direct contact. |
| **Reports** | Usage charts, traffic by region, anomaly detection. Needs aggregation pipeline + multi-day rollups. |
| **Audit log (client-visible)** | Per-client read of audit events. Admin has full audit; client view is a sub-product. |
| **Integrations** | Pre-built marketplace (Zapier, n8n, etc.). Needs API tokens to exist first. |
| **Team** | Multi-user accounts under one client (sub-users, role-scoped invites). Needs full RBAC model. |

The client portal sidebar **does not list these in v1** — they were removed from the "Coming next" section during the dev-handoff cut. They live in this roadmap as a record of product intent.

### Admin panel — v2 / Phase 2+ features

See `IMPLEMENTATION_BACKLOG.md` § Phase 2 for the admin-side Phase 2 list (granular RBAC, multi-role permission matrix, advanced reporting, Reports → Balances aggregation, etc.).

---

## Sequence summary

```
v1 frontend  ────────────────────────────────────────────►  [DONE]
v1 backend   ╔═════════════════════════════════════╗
             ║ schema → auth → lifecycle → live    ║       [IN PROGRESS]
             ╚═════════════════════════════════════╝
v1.5         ──┬── balance ledger ──┬── invoices ──┬── whitelist ──┬── rotation
               │                     │              │               │
               ▼                     ▼              ▼               ▼
              (ship incrementally as backend contracts complete)

v2           ──── support tickets / API tokens / reports / integrations / team / audit-client
```
