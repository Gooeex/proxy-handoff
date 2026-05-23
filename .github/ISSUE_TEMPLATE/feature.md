---
name: Feature
about: Implement a feature defined in the prototype / DEV_BRIEF
title: '[feat] '
labels: feature
---

## Scope

What this issue covers. Link the prototype file + section.

- Prototype: `prototypes/<file>.html`
- DEV_BRIEF section: §
- ADMIN_HANDOFF section: §
- DECISIONS reference (if applicable): §

## Acceptance criteria

- [ ] Frontend behavior matches the prototype 1:1 (click through to confirm)
- [ ] Backend writes/reads follow the documented contract
- [ ] Lifecycle transitions (if any) match `LIFECYCLE_CONTRACT.md`
- [ ] RLS / per-client isolation enforced (client-portal-facing endpoints)
- [ ] Audit log entry written (destructive actions)
- [ ] Tests cover the happy path + at least one error path

## Out of scope

What's NOT covered by this issue (file a separate one for those).

## Notes

Open questions, blockers, related issues.
