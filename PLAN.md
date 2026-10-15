# PlayersZWZ Implementation Plan

## Purpose

This plan turns the Phase 1 requirements and Phase 2 software design into a practical build sequence for a fully working PlayersZWZ application. It assumes the team will first review and reuse the Flutter app and backend work that already exists locally.

## Product scope

PlayersZWZ helps people find nearby sports games and players, organize matches, request arena bookings, and receive updates. The intended user roles are:

- **Player:** maintains sports preferences, finds games, requests to join, and provides feedback.
- **Organizer:** creates games, manages join requests, and requests arena bookings.
- **Arena manager:** manages arena information and responds to booking requests if included in the first release.
- **Administrator:** reviews reports and records moderation actions.

## Proposed technology and architecture

- **Mobile application:** Flutter for Android and iOS.
- **Backend:** Flask REST API, organized by product feature.
- **Authentication:** Firebase Authentication. The API validates Firebase ID tokens and applies role checks.
- **Database:** Cloud Firestore, accessed through the backend for product operations.
- **Maps and location:** Google Maps/Places integration, with manual-area entry when location permission is denied.
- **Notifications:** Firebase Cloud Messaging for push notifications and Firestore-backed in-app notifications.
- **Recommendations:** Start with explainable rules using sport preference, distance, availability, activity, and reliability. Improve the ranking only when useful usage history exists.

The mobile app should call the API for protected business operations. The API should enforce rules such as game capacity, duplicate join prevention, booking conflicts, and admin permissions.

## Implementation stages

The documents plan four two-week development sprints. This proposal adds a short foundation stage and a release stage around those feature sprints. Dates are intentionally omitted until the team confirms availability and the current state of its local app and API.

| Stage | Focus | Deliverable |
| --- | --- | --- |
| 0. Audit and foundation | Review existing Flutter/API code and prototypes; establish the main app and API structure, development configuration, Firestore rules/indexes, secret handling, and automated checks. | The team can run the app and API locally, and changes receive basic automated checks. |
| 1. Accounts and profiles | Registration, login, logout, Firebase token validation, roles, profile, sports, availability, radius, and location settings. | A user can create an account, sign in, and maintain their discovery preferences. Manual location remains available when GPS is denied. |
| 2. Nearby discovery | Map/list discovery for games and players, with sport, distance, and time filters; initial rule-based recommendations. | A user sees suitable nearby options and can understand the main reasons they were ranked. |
| 3. Games and joining | Create and view games, request to join, approve/reject requests, capacity checks, cancellation, and completion. | Organizer and player can complete the core join flow without duplicate requests or overfilling a game. |
| 4. Arenas and notifications | Arena discovery, slot display, booking requests, conflict checks, booking status, in-app notifications, push notifications, and reminders. | Users can request a booking and track status changes without conflicting slot confirmations. |
| 5. Trust and administration | Ratings, reports, no-show handling, reliability signals, admin review/actions, and audit history. | Reports are reviewed and actions are recorded; a single unverified report does not automatically impose a severe penalty. |
| 6. Test and release | Validate documented cases, regression-test core flows, verify Android/iOS builds, resolve usability issues, and prepare a demo/release build. | A stable build is ready for academic demonstration and a small user test. |

### Recommended first demo flow

1. Register and choose preferred sports.
2. Set current or manual location.
3. Find nearby games on a map or list.
4. Open a game and request to join.
5. Organizer approves the request.
6. Player receives an in-app or push notification.

This demonstrates the app's central value before the team expands into arena management, moderation, and advanced recommendation work.

## Proposed repository hierarchy

Keep the project documents and existing proof-of-concept apps. Add the integrated product in separate folders so production code is not confused with demos.

```text
PlayersZWZ/
├── README.md
├── docs/
│   ├── proposal/
│   ├── phase-01/
│   └── phase-02/
├── apps/
│   └── mobile/                         # Main Flutter application
│       ├── lib/
│       │   ├── app/                    # Startup, routing, theme
│       │   ├── core/                   # API client, config, errors, location
│       │   └── features/
│       │       ├── auth/
│       │       ├── profile/
│       │       ├── discovery/
│       │       ├── games/
│       │       ├── join_requests/
│       │       ├── arenas/
│       │       ├── bookings/
│       │       ├── recommendations/
│       │       ├── notifications/
│       │       ├── feedback/
│       │       └── admin/
│       └── test/
├── services/
│   └── api/                             # Main Flask API
│       ├── app/
│       │   ├── api/                     # Versioned routes
│       │   ├── auth/
│       │   ├── profiles/
│       │   ├── discovery/
│       │   ├── games/
│       │   ├── bookings/
│       │   ├── recommendations/
│       │   ├── feedback/
│       │   ├── notifications/
│       │   └── admin/
│       └── tests/
├── prototypes/
│   ├── gps-tracker/                     # Existing GPS proof of concept
│   └── ui-prototype/                    # Existing UI demonstration
├── infra/
│   ├── firebase/                        # Firestore rules and indexes
│   └── deployment/                      # Hosting configuration
└── .github/
    └── workflows/                       # Automated checks
```

Each mobile feature should keep its screens, data/API handling, and feature rules together. The backend should own authorization and rules that protect shared data. Keep credentials and private configuration out of Git.

## Core data areas

Use the Phase 2 schema as the initial model and refine it during implementation:

- `users` and `profiles`
- `games` and `game_participants`
- `arenas` and `booking_requests`
- `ratings_reports`
- `notifications`
- `admin_actions`

Use explicit status values and validate state changes through the API. For example, a join request moves through pending/approved/rejected/cancelled, while a booking has its own pending/approved/rejected/cancelled lifecycle.

## Quality and completion rules

A feature is ready when:

- Its acceptance criteria from the RS/SDS are met.
- The happy path and important edge cases are handled, including duplicate requests and unavailable slots.
- Loading, empty, permission-denied, offline, and error states are understandable.
- API authorization and role checks protect the operation.
- Relevant automated checks pass and the feature has been manually exercised on a device or emulator.
- The README or feature documentation explains any required setup.
- Jira work is linked through the branch, commit, and pull request where possible.

The documents set useful prototype targets: normal dashboard loading under three seconds, nearby results within five seconds, and support for around 50 academic test users without noticeable slowdown. Treat these as targets to measure in the test environment, not guarantees before testing.

## Scope to defer

Keep the first release focused on the main match-discovery and game-joining experience. Defer machine-learning recommendations, payments, tournaments, social login, badges, and a full arena-manager portal until the core flows are stable. The Phase 2 document lists these as future enhancements.

## Decisions to confirm before implementation

1. Should arena managers sign in and manage slots in the first release, or should an administrator handle booking approvals initially?
2. Which parts of the local Flutter app and backend already work, so the team can reuse them rather than rebuild them?
3. Is Android the first acceptance target, with iOS checked alongside it, or should both platforms be release blockers?

## Source documents

- `PlayersZWZ - Phase 01.pdf` — Software Requirements Specification, including epics, stories, acceptance criteria, sprint plan, and quality requirements.
- `PlayersZWZ - Phase - 02.pdf` — Agile Software Design Specification, including architecture, modules, schema, API contracts, tests, deployment considerations, and future enhancements.

