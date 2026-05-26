# Reference screenshots

Visual-regression baselines for every page in the prototype. Every PR that
touches a list / detail / form page should attach a **side-by-side diff**:
the matching PNG from this folder vs. the implementation under review.
The PR template enforces this.

## Layout

```
screenshots/
├── admin/                 ← prototypes/admin-panel.html
│   ├── dashboard-1440.png      desktop 1440×900
│   ├── dashboard-375.png       mobile  375×812
│   ├── orders-1440.png
│   ├── orders-375.png
│   ├── proxies-1440.png
│   ├── proxies-375.png
│   ├── plans-1440.png
│   ├── plans-375.png
│   ├── clients-1440.png
│   ├── clients-375.png
│   ├── payments-1440.png
│   ├── payments-375.png
│   ├── renewals-1440.png
│   ├── renewals-375.png
│   ├── settings-1440.png
│   ├── settings-375.png
│   ├── logs-1440.png
│   └── logs-375.png
├── client/                ← prototypes/client-panel.html (logged in)
│   ├── dashboard-1440.png
│   ├── dashboard-375.png
│   ├── proxies-1440.png
│   ├── proxies-375.png
│   ├── proxies-PXY-30412-1440.png    detail page
│   ├── proxies-PXY-30412-375.png
│   ├── orders-1440.png
│   ├── orders-375.png
│   ├── orders-ORD-10847-1440.png     detail page — active w/ 6 proxies
│   ├── orders-ORD-10847-375.png
│   ├── billing-1440.png
│   ├── billing-375.png
│   ├── catalog-1440.png
│   ├── catalog-375.png
│   ├── checkout-1440.png
│   ├── checkout-375.png
│   ├── settings-1440.png
│   └── settings-375.png
└── design-system/
    └── reference-1440.png         the foundation doc itself
```

## Viewports

Two are captured for every page:

| Tag    | Size      | Purpose                                 |
|--------|-----------|-----------------------------------------|
| `1440` | 1440×900  | Primary target. Sidebar + content + aside fit. Matches the design canvas. |
| `375`  | 375×812   | iPhone-class mobile. The page must collapse cleanly — no horizontal scroll, sidebar drawer behavior, KPI strip stacks. |

Other viewports (1024 tablet, 1920 wide-desktop) are not baselined yet. If
you find a layout breaks at one of those, file `bug` with a screenshot at
that size and we'll add it to the baseline set.

## Refreshing — how the PNGs are generated

```bash
cd path/to/proxy-handoff
bash scripts/capture-screenshots.sh
```

The script:

1. Starts a `python3 -m http.server` on port 8901 (kills any existing one).
2. For each admin route, opens `prototypes/admin-panel.html#<route>` in
   headless Chrome at each viewport and captures a PNG.
3. For each client route, opens `scripts/_auth-bootstrap.html?r=<route>`,
   which seeds a demo-user `cp_state_v1` into localStorage and redirects
   into `prototypes/client-panel.html#/<route>` — so the captured page is
   already logged in.
4. Writes PNGs to `screenshots/<surface>/<page>-<viewport>.png`.

**Re-run after every prototype change.** The PNGs *are* the contract — if
you change the prototype without refreshing them, the visual-regression
gate in the PR template starts comparing against a stale baseline.

### Requirements

- macOS with Chrome at `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`
  (override with `CHROME=/path/to/chrome bash scripts/...`)
- `python3`

The script uses Chrome's built-in headless `--screenshot` flag — no Node, no
Puppeteer, no Playwright install needed.

## How to use these in a PR

For every page touched in your branch:

1. Pull this folder; open the matching baseline PNG.
2. Capture the same route in your implementation at the same viewport.
3. Open both side-by-side in a diff tool (Preview's split view, Kaleidoscope,
   or paste both into the PR description as image attachments).
4. Tick the **"Side-by-side with the prototype — visuals + behavior match"**
   box in the PR template.

Differences that need addressing before merge:

- **Spacing / padding** off by ≥4px anywhere → fix.
- **Color** off in any token-driven place (panel bg, text, chip, accent) → fix.
- **Border radius** off → fix.
- **Type weight / size** off → fix.
- **Hover/focus/active states** differ → fix. (Test these by hovering in the
  implementation; the PNG only captures the rest state.)

Differences that are acceptable (and explicitly noted):

- Live data text content (timestamps, IDs, names) — the prototype uses
  static seed data, the implementation pulls from the DB.
- Skeleton/loading state in the implementation — the prototype renders
  instantly; the implementation may show a loader.

If you find the prototype itself is wrong (a UX bug, an a11y issue), file
`bug` against the prototype and refresh the PNGs once it's fixed.

## Notes on the bootstrap loader

`scripts/_auth-bootstrap.html` is an internal capture tool, not a deliverable.
It pre-seeds the client-portal localStorage with a logged-in demo state so
headless Chrome can capture pages behind auth without a real login flow.
**Do not link to it from the production app.** It will be removed when the
real backend ships and the prototype is retired.
