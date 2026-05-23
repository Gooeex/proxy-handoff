# Proxy — Subscription Platform Handoff

Implementation handoff for a SaaS proxy-subscription product. Contains two clickable prototypes (admin + client portal) and the documentation needed to build the production system.

**Stack target:** Railway (hosting) + Supabase (Postgres + Auth + Storage). Backend dev has discretion on the frontend stack — React/Next/Vue/whatever — but the prototypes are the canonical UX spec.

---

## Quick start

```bash
# Serve the prototypes locally (no build step — pure HTML)
cd prototypes
python3 -m http.server 8000
# Then visit:
#   http://localhost:8000/client-panel.html        ← client portal
#   http://localhost:8000/admin-panel.html         ← admin panel
#   http://localhost:8000/design-system-reference.html  ← design system spec
```

**Demo credentials (client portal):** `demo@example.com` / `demo1234`

---

## What to read, in order

1. **[`DEV_BRIEF.md`](./DEV_BRIEF.md)** — start here. The entry-point implementation brief covering both surfaces, the build target, what to preserve, what not to do, Phase 1 scope, security/auth posture.
2. **[`ADMIN_HANDOFF.md`](./ADMIN_HANDOFF.md)** — admin-side data model, entity lifecycle, edge cases, validation contracts. The deepest reference for "how the platform actually works".
3. **[`DECISIONS.md`](./DECISIONS.md)** — product decisions taken during the 2026-05-23 handoff audit. Stage 1.5 backend contracts. **Do not re-litigate these without owner sign-off.**
4. **[`LIFECYCLE_CONTRACT.md`](./LIFECYCLE_CONTRACT.md)** — required state-machine contracts for Order / Payment / Proxy. **Sign this off before writing any mutation code.**
5. **[`IMPLEMENTATION_BACKLOG.md`](./IMPLEMENTATION_BACKLOG.md)** — phased work breakdown (Phase 0 → Phase 2).
6. **[`ROADMAP.md`](./ROADMAP.md)** — v1 / v1.5 / v2 scope. What ships first, what's parked.

Open the two prototypes side-by-side with `DEV_BRIEF.md` and `ADMIN_HANDOFF.md` — the docs reference specific files/sections, and the prototypes ARE the spec.

---

## Repo layout

```
.
├── README.md                          ← you are here
├── DEV_BRIEF.md                       ← master implementation brief
├── ADMIN_HANDOFF.md                   ← admin data model + lifecycle + validation
├── DECISIONS.md                       ← Stage 1.5 product decisions
├── LIFECYCLE_CONTRACT.md              ← state-machine contracts
├── IMPLEMENTATION_BACKLOG.md          ← phased work breakdown
├── ROADMAP.md                         ← v1 / v1.5 / v2
├── prototypes/
│   ├── client-panel.html              ← client portal prototype (canonical UX)
│   ├── admin-panel.html               ← admin panel prototype (canonical UX)
│   └── design-system-reference.html   ← design system spec — see note below
└── .github/
    ├── ISSUE_TEMPLATE/                ← feature.md, bug.md
    └── pull_request_template.md
```

> **Note on `design-system-reference.html`:** this file is the design system spec that was originally written for the **admin panel** — most of the components it documents (bulk-bar, `.dt` tables with admin filters, multi-column detail layouts) are admin-side. The **design tokens** (typography ramp, spacing, semantic colors, `.kv-row` rhythm, panel/card primitives) carry over directly to the client portal. The **client portal** uses the same tokens but with a few deliberate adjustments: warmer cream/gold accent palette, narrower max-width per page, slimmer KPI strip, no bulk-bar. Use the admin spec as the foundation, and treat `prototypes/client-panel.html` as the source of truth where the client deviates.

---

## Workflow

- **Issues:** every implementation task starts as a GitHub Issue. Tag with `phase:0` / `phase:1` / `phase:2` (or `stage:1.5`) to match `IMPLEMENTATION_BACKLOG.md`.
- **Branches:** feature branches off `main`. Naming: `feat/<page>-<short>`, `fix/<short>`, `chore/<short>`.
- **PRs:** open against `main`. PR description follows the template — reference the issue, describe the diff, list manual test steps.
- **Reviews:** at least one approval before merge.
- **Prototype as truth:** if a question comes up about behavior or visuals, the prototype is the source of truth — open the relevant HTML, click through the flow, copy the visible behavior 1:1. If the prototype is ambiguous, file an issue tagged `question:product` and tag the product owner.

---

## What's intentionally NOT in this repo

These belong elsewhere (CI/CD secrets, infra, etc.):

- `.env` files, deploy keys, Supabase service-role keys
- `node_modules/`, build artifacts
- Production database dumps
- Railway / Supabase project configs (set those up in Railway/Supabase consoles directly)

---

## Contact

- **Product / scope / decisions questions:** open an issue with the [`question` template](./.github/ISSUE_TEMPLATE/question.md) → tag `question:product`
- **Visual / interaction design questions:** open an issue → tag `question:design`
- **Bugs / discrepancies vs. the prototype:** open an issue with the [`bug` template](./.github/ISSUE_TEMPLATE/bug.md)

When in doubt — open an issue rather than guessing. The product owner reads them and replies inline.
