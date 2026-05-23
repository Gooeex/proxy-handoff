# Implementation Backlog

Working backlog for the production implementation. Captured here so the prototype phase hands off cleanly.

**Do not execute these items during the prototype phase.** They are pre-recorded work items for the implementation team.

Status legend: `todo` / `wip` / `done` / `blocked`.
Priority legend: **P0** unblocks Phase 1 ship · **P1** must land for full functional MVP · **P2** Phase 2 · **P3** later polish.

---

## Phase 0 — Handoff hygiene

| ID | Title | Problem | Required change | Files / area | Priority | Acceptance criteria |
|---|---|---|---|---|---|---|
| H1 | Confirm `DEV_BRIEF.md` is up to date | Spec drift risk between brief and prototypes | Diff against actual file inventory + Stage 1.5 markers | `DEV_BRIEF.md`, both HTML files | P0 | DEV_BRIEF lists current files, current Phase 1 scope, current Stage 1.5 markers |
| H2 | Align README with DEV_BRIEF | README should point dev to DEV_BRIEF first | "Read DEV_BRIEF.md first" note at top | `prototypes/admin-panel.html` README (legacy — see ADMIN_HANDOFF.md) | P0 | Reader lands on DEV_BRIEF before exploring HTML |
| H3 | Confirm file inventory (admin + client) | Sandbox vs canonical file confusion previously caused incorrect edits | List exact paths to both HTML files; mark `client-panel.html` (no suffix) as sandbox | `DEV_BRIEF.md`, `README.md` | P0 | New reader cannot confuse v1 with sandbox |
| H4 | Confirm `validatePrototypeData()` status | Mentioned in README; verify it still runs | Open console, run, paste output into README freshness note | `prototypes/admin-panel.html` README (legacy — see ADMIN_HANDOFF.md) | P1 | README states current invariant pass/fail count |
| H5 | Mirror Stage 1.5 marker convention into admin if symmetric | Admin doesn't currently flag backend-pending items by class | If any admin UI is similarly stubbed, port `.stage15-badge` pattern from client | `prototypes/admin-panel.html` | P2 | grep symmetry between both files |

---

## Phase 1 — Core production foundation

| ID | Title | Problem | Required change | Files / area | Priority | Acceptance criteria |
|---|---|---|---|---|---|---|
| C1 | Create DB schema (shared admin + client) | No production DB yet | Postgres migration matching `HANDOFF.md § Data model` | `supabase/migrations/0001_init.sql` | P0 | `supabase db push` succeeds; all FKs resolve; validator-equivalent invariants enforceable |
| C2 | Implement admin SPA shell | No real frontend | Layout grid, sidebar (9 items), topbar, router, design tokens | new SPA repo | P0 | Routes match prototype hash routes; tokens load from shared CSS module |
| C3 | Extract design tokens | Tokens live inline in prototype | Lift `:root` block from `prototypes/admin-panel.html` into `tokens.css` | new SPA repo | P0 | Tokens imported as module; both surfaces share file |
| C4 | Build `DataTable` primitive | `.dt` system is HTML-only | Reusable component: colgroup, anchor tokens, semantic column classes, sort/filter/paginate hooks | new SPA repo | P0 | Admin Orders list renders 1:1 visually against prototype |
| C5 | Formalise Order lifecycle contract | Implicit in seed data | Extract into `LIFECYCLE_CONTRACT.md` and sign off | `LIFECYCLE_CONTRACT.md` | P0 | All transitions enumerated; initiator labelled per transition |
| C6 | Formalise Payment lifecycle contract | Same | Same as C5 for payments | `LIFECYCLE_CONTRACT.md` | P0 | Same |
| C7 | Formalise Proxy assignment contract | Currently scattered: assignment, release, replacement, faulty all interact | Single state machine spec; identify what releases a proxy | `LIFECYCLE_CONTRACT.md` | P0 | Race-condition test plan defined |
| C8 | Implement Orders list | First list page | Backend list endpoint with filters; SPA renders via `DataTable` | new SPA repo | P0 | Filter/pagination/tab behavior matches prototype |
| C9 | Implement Order Detail | First detail page | Backend fetch + assignment history + activity widget | new SPA repo | P0 | Visual + behavioral 1:1 against prototype |
| C10 | Implement proxy assignment/release mutation | Transaction-safe inventory | Postgres function or backend RPC inside a transaction | new SPA repo + migrations | P0 | Concurrent-assignment test passes; capacity invariant holds |
| C11 | Implement Audit Log for critical transitions | Compliance + ops debuggability | Per-mutation log row with actor, action, object_type, object_id, detail | new SPA repo | P0 | Every destructive mutation produces a log entry |
| C12 | Implement client portal shell | Second SPA | Sidebar (5 items: Dashboard / Proxies / Orders / Billing / Settings), topbar, design tokens | new SPA repo | P0 | Matches `prototypes/client-panel.html` layout |
| C13 | Implement client auth + per-client data isolation | **Phase 1 REQUIREMENT (not deferred)** | Supabase auth + RLS policies on every client-readable table | new SPA repo + migrations | P0 | Cross-client read attempts return empty / 403 in tests |
| C14 | Implement client Order view | Client read-only of own orders | Backend list/detail endpoints scoped by `auth.uid()` | new SPA repo | P0 | Client sees own orders only; no admin-only fields leak |
| C15 | Implement client renewal/replacement request flow | Currently UI-only on client side | Backend queue table + admin notification + client status visibility | new SPA repo + `client_requests` table | P0 | Client request appears in admin Order Detail; admin processes; client sees status |

---

## Phase 1.5 — Stage 1.5 backend (currently UI-only on client portal v1)

These map 1:1 to the `.stage15-badge` markers in `prototypes/client-panel.html`. Each item must ship a backend before its UI badge can be removed.

| ID | Title | Problem | Required change | Files / area | Priority | Acceptance criteria |
|---|---|---|---|---|---|---|
| S1 | Implement `client_balance_ledger` | Account balance UI is in client portal v1 with no backend | Append-only ledger table; 4 op_types (topup / order_debit / refund_credit / manual_adjust); SUM-derived balance | new table + admin Balance panel + Adjust modal | P1 | Balance UI shows real numbers; admin can adjust with audit |
| S2 | Implement `invoices` entity | Invoice column in Transactions has no backend | Separate entity (`INV-YYYY-NNNNN`); 1:1 with confirmed payments; PDF generated on payment confirm | new table + admin Payment Detail + client Invoices tab | P1 | Download produces a real PDF; admin sees Invoice link |
| S3 | Implement `proxy_whitelist` + edge enforcement | Whitelist panel in client Proxy Detail has no backend | Table (cap 5/proxy); gateway checks `source_ip ∈ whitelist` before forwarding | new table + gateway hook + admin Proxy Detail read-only panel | P1 | Non-matching source IP returns HTTP 403 at gateway |
| S4 | Implement Plan rotation policy fields | Rotation policy UI in client is plan-driven in concept but not in DB | Add `rotation_policies_allowed array`, `auto_interval_min_choices number[]` to plans; admin Plan form exposes both | `plans` migration + admin Plan Edit | P1 | Client sees auto/url options only when plan allows; intervals match plan-defined choices |
| S5 | Implement `provider_id` enum + display mapping | `payment.provider` is currently free-form string | Add `provider_id` enum (stripe/coinpayments/bank_transfer/paypal); API maps internal → display | `payments` migration | P2 | Client sees "Card" / "Crypto" / "Bank transfer" / "PayPal"; admin sees internal id + alias |
| S6 | Implement Plan `internal_name` + `display_name` | Plans currently have a single `name` | Add `internal_name` (admin-facing) and `display_name` (client-facing) fields; admin Plan form exposes both | `plans` migration + admin Plan form | P1 | Admin endpoints return `internal_name`; client endpoints return `display_name` |
| S7 | Implement credentials delivery tracking | Client-side credentials reveal is not "delivery" | `credentials_sent_at` + `credentials_channel` + `credentials_delivery_status` columns | `orders` migration | P2 | Client banner shown when `credentials_sent_at IS NULL` |

---

## Phase 1.5 — Integrations

| ID | Title | Problem | Required change | Files / area | Priority | Acceptance criteria |
|---|---|---|---|---|---|---|
| I1 | Payment webhook handling | No real money flow yet | Stripe + CoinPayments webhooks → Edge Function → state machine entry | new Edge Function | P0 | Real `payment.confirmed` event drives `order.activate` |
| I2 | Proxy hardware/API integration | No real proxies yet | Per-vendor adapter layer; health/uptime/latency reporting | backend integration layer | P0 | Real proxy health flows to `proxies.health` column |
| I3 | Scheduled renewal/expiry sweep | `sweepPendingRenewals()` in prototype is mock | Cron + Edge Function: auto-cancel stale pending-renewal, auto-release on grace timeout | new Edge Function | P1 | Stale orders cancelled within grace window |
| I4 | Basic notification hooks | Template records exist in seed but no dispatcher | Edge Function queue worker: render template against context, send email (SendGrid/Resend) and Telegram (bot API) | new Edge Function | P1 | `payment.confirmed` delivers an email to the client |

---

## Phase 2 — Deferred hardening

| ID | Title | Problem | Required change | Files / area | Priority | Acceptance criteria |
|---|---|---|---|---|---|---|
| D1 | Full admin RBAC | Phase 1 = Super Admin only | Activate Operations / Support roles; per-action policy matrix from `HANDOFF.md § Auth & roles` | `current_admin_role()` + UI | P2 | Each role sees / can do only what the matrix allows |
| D2 | Supabase RLS policies (admin) | Phase 1 lacks granular admin policies | Full RLS policy set keyed off `current_admin_role()` | `supabase/migrations` | P2 | Penetration test passes |
| D3 | 2FA for admins | Phase 1 doesn't enforce | TOTP via Supabase Auth | admin SPA | P2 | All admins must enroll within enforcement window |
| D4 | Rate limiting | Public + admin endpoints | API gateway or Edge Function middleware | backend | P2 | Bursts blocked at configurable rate |
| D5 | Error boundaries (both SPAs) | Currently no fallback UI | React error boundary at route level | both SPAs | P2 | Crashes show fallback, not white screen |
| D6 | Accessibility audit | Prototype is desktop-mouse-first | WCAG AA pass; keyboard navigation; aria roles | both SPAs | P3 | Lighthouse a11y ≥ 95; tab order verified |
| D7 | Observability | No logs/metrics/traces yet | Structured logs + OTEL traces + metric collection | backend + SPA telemetry | P2 | Dashboard exists for incident triage |
| D8 | Multi-operator conflict handling | Two admins editing same Order Detail | Optimistic concurrency via `updated_at` token; conflict UI | admin SPA | P3 | Conflicting saves prompt instead of silently overwriting |
| D9 | Webhook management (admin Settings → API / Webhooks) | Section is static markup in prototype | Full feature: list + Add/Edit modal + Test webhook + delivery history with retry status | new tables + UI | P2 | Admin can configure outbound webhooks with signing |
| D10 | Activity log retention | `admin_logs` grows unbounded | Choose policy (90d / 1y / archive to S3); implement sweep | backend | P3 | Retention sweep runs on cron; oldest rows trimmed |

---

## Notes

- New items: add a row, give it a unique ID (next sequential per phase), note acceptance criteria.
- Don't delete completed items — flip status to `done` for history.
- Cross-reference IDs from commit messages and PR descriptions (e.g. `[C10]`).
