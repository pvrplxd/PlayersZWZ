# Sprint 1 source audit

## Sources reviewed

- Connected GitHub repository `pvrplxd/PlayersZWZ`, default branch `main`, including `README.md` and `PLAN.md`.
- Jira active work: SCRUM-18 (assigned to Afaq Bin Aamir), SCRUM-19 (Hassan Ahmad), SCRUM-20 (Waleed Abid).

## Current repository state

The upstream GitHub README describes the original repository as project documentation plus two Flutter demos: `prototypes/ui-prototype/` and `prototypes/gps-tracker/`. Those are references, not the complete production app/backend. The supplied UI screenshots are now available locally under `UI Screens/` and documented in `docs/UI_DESIGN_SYSTEM.md`.

| Area | State | Next action |
| --- | --- | --- |
| Product and technical plan | Reusable | Follow Sprint 1 and Sections 4–9 of `PLAN.md` |
| Flutter UI prototype | Screen references are in `UI Screens/`; first-pass design system documented | Confirm exact design tokens and interaction details against editable source if available |
| GPS tracking PoC | Prototype folder exists locally; source audit pending | Audit location permission and map flow before porting |
| Production Flutter app | Flutter Android/iOS scaffold exists under `apps/mobile/` | Add Firebase initialization and auth after config files are copied into ignored local paths |
| Flask API | Health-endpoint scaffold exists under `services/api/` | Add Firebase Admin initialization and product routes in planned phases |
| Firebase/Maps configuration | Team prerequisites | Follow `SETUP.md`; keep credentials out of Git |
| Firestore rules/indexes | Planned, not implemented here | Add before any client or backend deployment |

## Sprint 1 alignment

This local scaffold contains the Flutter Android/iOS app, Flask health endpoint, and initial folder layout. Firebase client config files are owned by Afaq and should be copied into the documented ignored paths before auth wiring. The supplied screens are recorded in `docs/UI_DESIGN_SYSTEM.md`; exact fonts and some interaction details remain open.

