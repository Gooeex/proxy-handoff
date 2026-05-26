# Developer Brief — Proxy Subscription Platform

> **Read me first.** This file is the entry point for anyone implementing the production system. Read DEV_BRIEF in full, then `ADMIN_HANDOFF.md`, then `prototypes/design-system-reference.html`, then click through the prototypes.

## Status

The two HTML files at:

- `prototypes/admin-panel.html` (~15,100 lines)
- `prototypes/client-panel.html` (~9,300 lines, the "v1 clean" handoff cut)

…are **clickable prototypes** — UX/product specifications, not production code. They run as static HTML in a browser, persist mock state to `localStorage`, and ship hardcoded seed data.

The platform has **two surfaces** that share a single backend and database:

| Surface | Prototype file | Users |
|---|---|---|
| Admin panel (operator) | `prototypes/admin-panel.html` | Internal Super Admins |
| Client portal (buyer) | `prototypes/client-panel.html` | External clients |

## Build target

- **Hosting:** Railway
- **Database + Auth + Storage:** Supabase (Postgres) — strongly recommended for fast iteration on auth + RLS; backend dev has discretion on the frontend stack within the constraints below
- **Frontends:** production SPAs (admin + client) connected to the same backend
- **Source of truth:** backend / database. Frontends are views, not models.

## Frontend stack constraints — pixel-perfect requirement

The prototypes are the canonical visual + interaction spec. The shipped product must match them 1:1 — same dimensions, paddings, colors, transitions, hover/focus/active states, spacing rhythm. To make that achievable:

### Allowed

- **Vanilla CSS** — preferred. The CSS in the prototypes is already production-shaped: lift it as-is.
- **CSS Modules / styled-components / vanilla-extract / Emotion** — fine, provided every value is copied verbatim from the prototype.
- **Tailwind** — allowed *only* if every token in `tailwind.config.{js,ts}` is hardcoded from the prototype's `:root` block (no Tailwind defaults for colors, spacing, radii, font sizes — those are wrong and will diverge).

### Forbidden

- **No opinionated UI kits.** No MUI / Material-UI, Chakra, Ant Design, Mantine, Radix Themes, Bootstrap, Bulma, daisyUI, NextUI, shadcn-with-defaults, etc. They impose their own tokens and component geometry and the result will not be pixel-perfect. Unstyled primitives (Radix UI Primitives, Headless UI, React Aria) are fine because they ship no visuals.
- **No "improvements"** to spacing, type sizes, radii, border colors, hover states, focus rings, or transitions. If a value looks off, file `question:design` — do not silently edit.
- **No reinvented animations.** Transitions in the prototype are short (`120ms`) on `border-color` / `transform` / `color`. Copy them; do not extend.
- **No icon-set swaps.** Icons in the prototypes are inline SVG (Lucide outline, 16×16, stroke-width 1.5). Use the same set.

### Workflow

Open the relevant prototype in Chrome → DevTools → Inspect the target element → copy Computed styles → port into your stack. The prototype is the source of truth; the dev's own taste is not. If the prototype is ambiguous (two states look similar, an interaction is unclear), open an issue tagged `question:design` instead of guessing.

### Token migration

The `:root` block at the top of `prototypes/client-panel.html` (lines 19–89) and `prototypes/admin-panel.html` (lines 19–55) carries every token. Lift them as-is into a single `tokens.css` (or framework-native equivalent) and reference them everywhere. **Do not redefine tokens per-component.** Admin and client portals have meaningfully different palettes — see `prototypes/design-system-reference.html` §7 ("Client portal deltas") for the comparison table.

### Visual regression gate

Every PR that touches a list / detail / form page includes side-by-side screenshots (prototype vs implementation) at desktop (1440px) and mobile (375px). Reference shots live in `screenshots/` and should be refreshed when the prototype changes. The PR template enforces this via the "Side-by-side with the prototype" checkbox.

## Source files

| File | Purpose |
|---|---|
| `prototypes/admin-panel.html` | Admin panel prototype (canonical UX/UI spec, admin side) |
| `prototypes/client-panel.html` | Client portal prototype (canonical UX/UI spec, client side) |
| `prototypes/design-system-reference.html` | Design system spec — typography, spacing, color, components, patterns |
| `ADMIN_HANDOFF.md` | Admin-side implementation guide — data model, edge cases, auth roles, validation contracts |
| `DECISIONS.md` | Product decisions from the 2026-05-23 audit session (Stage 1.5 contracts) |
| `ROADMAP.md` | v1 / v1.5 / v2 split — what's frontend-ready, what's pending backend, what's parked |
| `IMPLEMENTATION_BACKLOG.md` | Phased work breakdown (Phase 0 → Phase 2) |
| `LIFECYCLE_CONTRACT.md` | Required state-machine contract to extract and sign off before backend mutation code |

## What to preserve from the prototypes

- UX structure on both surfaces (sidebar/topbar/main layout, page composition habits)
- Visual design system (tokens, type ramp, table patterns)
- Navigation model and sidebar order (admin: 9 items; client: 5 items — Dashboard / Proxies / Orders / Billing / Settings)
- Table system (`.dt` with anchor tokens, colgroups, semantic column classes — `prototypes/design-system-reference.html` § 3.2`)
- Detail page layout (kv-row rhythm, aside panels, activity strips)
- Bulk-bar behavior (admin only — `prototypes/design-system-reference.html` § 3.9`)
- Order / Payment / Proxy / Renewal lifecycle semantics (see `LIFECYCLE_CONTRACT.md`)
- Inventory + capacity logic (derived `display_available`, capacity-state chip)
- Exception handling (paid-not-provisioned, renewal-not-extended, replacement-pending, refund-pending)
- Audit log expectations
- Client-facing UX: order status visibility, renewal flow, proxy credentials reveal, replacement/refund request affordances

## What not to do

- **Do not** ship `prototypes/admin-panel.html` or `prototypes/client-panel.html` as production frontends.
- **Do not** refactor either HTML file in place into production.
- **Do not** use mock JS seed data (`db` in admin, `State` in client) as real persistence — it's spec, not data.
- **Do not** use `localStorage` as production persistence.
- **Do not** bypass audit logging for destructive actions.
- **Do not** implement proxy assignment/release as frontend-only logic — must be a transaction-safe backend operation.
- **Do not** treat dashboard counters as manually maintained truth — derive from queries.
- **Do not** let the client portal write order/payment/proxy state directly. Client actions are intents/requests; backend validates and mutates.
- **Do not** expose admin-only data or other clients' data to the client portal.
- **Do not** duplicate lifecycle logic in admin and client frontends — it lives in the backend.

## Phase 1 implementation scope

The MVP that goes live first. Items are listed roughly in dependency order.

1. **Database schema and migrations** — single source of truth for both surfaces. See `HANDOFF.md § Data model`.
2. **Core SPA shell (admin)** — layout, routing, design tokens lifted from `prototypes/design-system-reference.html`.
3. **Orders list + Order Detail** — first list page + first detail page.
4. **Payment records and payment status handling** — manual mutation acceptable for MVP until webhook integration lands.
5. **Proxy inventory and assignment** — `order_proxy_assignments` is the source of truth; `order.proxy_id` and `proxy.current_order_id` are denormalized mirrors.
6. **Order / Payment / Proxy lifecycle state machine** — backed by the formal contract in `LIFECYCLE_CONTRACT.md` once signed off.
7. **Plans and capacity logic** — derived `display_available`; capacity-state chip computed.
8. **Clients.**
9. **Audit Log** — every destructive transition and admin action.
10. **Basic Settings** — provisioning rules, grace periods, system flags, display defaults.
11. **Minimal Super Admin access model** for admin panel — see Security/Auth section below.
12. **Client portal shell + client authentication + strict per-client data isolation** — required Phase 1.
13. **Client order view + client renewal/replacement request flow** — requests written to backend queue; admin processes.
14. **Payment webhook integration** — Stripe / CoinPayments / Bank transfer. May land in Phase 1.5 if QA gates first.
15. **Proxy hardware/API integration** — per-vendor adapter layer. May land in Phase 1.5.

## Stage 1.5 — backend-pending UI in client portal

The client portal v1 includes several UI surfaces whose backend isn't wired yet. They are marked in-file with a `.stage15-badge` ("v1.5" amber pill) and a hover tooltip describing the missing backend contract.

Find them all:

```bash
grep -n "stage15-badge" "prototypes/client-panel.html"
```

Currently marked (5 surfaces):

| Where | Missing backend |
|---|---|
| Billing → Account balance card | `client_balance_ledger` table (append-only; op_types: topup / order_debit / refund_credit / manual_adjust) |
| Billing → Transactions → Invoice column | `invoices` entity (`INV-YYYY-NNNNN`); 1:1 with confirmed payments; PDF on confirm |
| Proxy Detail → Whitelist panel | `proxy_whitelist` table + edge enforcement at the gateway (cap 5 entries, source-IP check) |
| Proxy Detail → Rotation URL panel | Plan-level `rotation_policies_allowed` field |
| Proxy Detail Info aside → Auto rotation kv-row | Plan-level `auto_interval_min_choices` field |

Each badge's hover tooltip carries a one-sentence summary of the backend contract. **Do not remove a badge until its endpoint ships + integration test passes.**

## Security / Auth — two-surface policy

The two surfaces have **different** Phase 1 security postures. Read this carefully.

### Admin panel — Phase 1: Super Admin only

- All Phase 1 admin users are trusted internal operators with `role = 'super'`.
- **Not blockers for admin MVP:** granular RBAC, multi-role permission matrix, 2FA, advanced rate limiting, full RLS policy matrix.
- However, the database schema must not prevent adding roles / RLS later — keep the `admins.role` column and `current_admin_role()` function from `HANDOFF.md § Auth & roles`, even if all Phase 1 admins have `role = 'super'`.
- Destructive actions must still write to the audit log.

### Client portal — Phase 1: REQUIRED, not deferred

- External users are **untrusted**.
- Client authentication (email + password, or magic link) is required.
- Strict per-client data isolation: a client must never see another client's orders, proxies, payments, invoices, or credentials.
- Enforce isolation at the API layer **and** with Supabase RLS keyed off `auth.uid()`.
- No leakage of admin-only data (audit logs, plan `internal_name`, other clients' info) to client endpoints.

### Always required, both surfaces

- No secrets in frontend (no API keys, webhook secrets, payment provider service-role keys).
- Backend-only payment/proxy operations — webhooks authenticated server-side, not trust-based frontend calls.
- Destructive actions write to audit log.

## Deferred — Phase 2 (admin hardening)

- Full admin RBAC (Operations / Support tiers per `HANDOFF.md § Auth & roles`).
- Supabase RLS hardening for admin endpoints.
- 2FA for admins.
- Granular admin permissions matrix.
- Notification dispatch engine (templates exist; need queue worker).
- Advanced webhook management section.
- Activity-log retention policy.
- Accessibility audit (WCAG AA).
- Error boundaries.
- Advanced observability (tracing, structured logs, metrics).
- Multi-operator concurrency controls beyond basic transactional safety.

## Critical implementation principles

- **Backend/database is the single source of truth** for both surfaces.
- **Order status cannot transition without validating** payment state and (if applicable) proxy assignment state.
- **Proxy assignment / release must be transaction-safe.** Race conditions on inventory are real risks.
- **Capacity should be derived,** not maintained by hand.
- **Audit log must record** important state transitions and any destructive admin action.
- **Client portal actions are intents/requests**; backend authorizes and executes.
- **Mock-only UI actions** in either prototype must become real backend commands or be explicitly removed before ship.

## Recommended implementation order

Follow the Phase 1 numbering above (1 → 15) for build sequence.

- Items 1–3 unblock the rest (schema → shell → first list/detail).
- Items 5–6 (proxy assignment + state machine) are the most error-prone — sign off `LIFECYCLE_CONTRACT.md` **before** writing mutation code.
- Item 12 (client portal auth) can start in parallel with admin work once items 1–3 land.
- Items 14–15 (integrations) gate go-live but can be stubbed during earlier sprints.

## First tasks for developer

A concrete checklist to start work — first 10 items:

1. Spin up a Supabase project and a Railway service for the SPA(s).
2. Translate `HANDOFF.md § Data model` into `supabase/migrations/0001_init.sql`. Run it.
3. Seed the database with a minimal fixture (5 clients, 3 plans, 10 orders, 5 proxies, payment per order). Don't import the prototype seed verbatim — write a clean fixture script.
4. Stand up the admin SPA shell: sidebar + topbar + router + layout grid + design tokens from `prototypes/design-system-reference.html` § 1` and `:root` block in `prototypes/admin-panel.html`.
5. Build the `<DataTable>` primitive matching `.dt` semantics (anchor tokens, colgroup, semantic column classes).
6. Implement Orders list (tabs + filters + pagination + selection set).
7. Implement Order Detail (kv-rows + lifecycle + activity widget + assignment history).
8. Implement the proxy assignment / release mutation as a transaction-safe backend RPC.
9. Stand up the client portal SPA shell + Supabase auth + per-client RLS policies.
10. Implement client-facing Order list + Order detail (read-only for state; intent-form for renewal/replacement).

After these ten land, return to `IMPLEMENTATION_BACKLOG.md` for the next phase.
