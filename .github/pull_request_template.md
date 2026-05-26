## Summary

Brief description of the change. Reference the issue this PR closes.

Closes #

## Prototype reference

- File: `prototypes/<file>.html`
- Section: §

## Diff overview

- What changed (in plain English, not file-by-file)
- New dependencies (if any)
- Schema migrations (if any)

## Test plan

How you verified this works.

- [ ] Manual: clicked through the relevant flow in the implementation
- [ ] **Side-by-side with the prototype** — pixel-checked against `screenshots/<surface>/<page>-1440.png` and `screenshots/<surface>/<page>-375.png`. Spacing, type, colors, radii, hover/focus/active states match. **Diff PNGs attached below.**
- [ ] Hover / focus-visible / active / disabled states verified per affected component
- [ ] Mobile (375×812) layout verified — sidebar drawer, KPI stack, no horizontal scroll
- [ ] Unit / integration tests added or updated
- [ ] RLS verified (no cross-client data leak, no admin-only access from client)
- [ ] Audit log entries written for destructive actions

## Out of scope

What this PR explicitly does NOT do — file follow-up issues for those.

## Screenshots

For any UI change, attach **two** side-by-side comparisons:

1. **Desktop (1440×900):** prototype baseline (`screenshots/<surface>/<page>-1440.png`) vs implementation
2. **Mobile (375×812):** prototype baseline (`screenshots/<surface>/<page>-375.png`) vs implementation

If the baseline is stale (prototype was changed in this PR), refresh it: `bash scripts/capture-screenshots.sh` and commit the updated PNGs.
