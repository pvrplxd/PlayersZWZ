# PlayersZWZ — Implementation Plan

> **AI-Powered Sports Matchmaking & Arena Booking Application** · BSCS Final Year Project · Group S26CS024 · University of Central Punjab
> Project Advisor: Mr. Asif Farooq · Team: Waleed Abid, Afaq Ul Islam, Hassan Ahmed
> Plan version: 2.0 · Last checked against Jira and the SRS/SDS: 15 October 2026

---

## Table of contents

1. [Prerequisites (accounts, keys, tools)](#1-prerequisites-accounts-keys-tools)
2. [Jira sprint map](#2-jira-sprint-map)
3. [Product scope and roles](#3-product-scope-and-roles)
4. [Architecture and tech stack](#4-architecture-and-tech-stack)
5. [Repository structure](#5-repository-structure)
6. [Environment configuration and secrets](#6-environment-configuration-and-secrets)
7. [Data model (Firestore)](#7-data-model-firestore)
8. [API reference](#8-api-reference)
9. [Sprint-by-sprint implementation](#9-sprint-by-sprint-implementation)
10. [Recommendation logic](#10-recommendation-logic)
11. [Notification matrix](#11-notification-matrix)
12. [Test plan](#12-test-plan)
13. [Git workflow and Definition of Done](#13-git-workflow-and-definition-of-done)
14. [Scope deferred](#14-scope-deferred)
15. [Open decisions and document inconsistencies](#15-open-decisions-and-document-inconsistencies)
16. [Risks](#16-risks)
17. [Demo flow](#17-demo-flow)

---

## 1. Prerequisites (accounts, keys, tools)

Nobody should start a feature until the items marked **Blocker** are done. Items are grouped by who normally needs them.

### 1.1 Accounts and services (one shared owner creates, everyone gets access)

| # | Item | Why it is needed | Needed by | Blocker for |
|---|------|------------------|-----------|-------------|
| P-01 | **GitHub repository** with `main` and `develop` branches, all three members added | Shared code, PR reviews, CI | All | Sprint 1 |
| P-02 | **Jira SCRUM board** access (all members) | Branch/PR linking to issues, e.g. `SCRUM-12` | All | Sprint 1 |
| P-03 | **Firebase project** (e.g. `playerszwz-dev`) on a Google account the whole team can access | Auth, Firestore, FCM | All | Sprint 1 |
| P-04 | **Geoapify account and API key** | Map tiles, Places, and geocoding for mobile map/location flows | Afaq | Sprint 1 map work |
| P-05 | Hosting account for the Flask API (Render, Google Cloud Run, Heroku or AWS EB; the SDS allows any) | Reachable backend for physical-device testing and the jury demo | Waleed | Sprint 1 end / Sprint 4 |
| P-06 | **Apple Developer account** (paid) *only if* iOS push notifications are a release requirement | iOS FCM needs an APNs key. Without it, iOS runs but gets no push | Afaq | Sprint 4 (iOS push) |

### 1.2 Firebase configuration checklist

- [ ] **Authentication**: enable **Email/Password**. (Google sign-in is shown in the UI prototype but is deferred; see Section 15.)
- [ ] **Cloud Firestore**: create the database in **production mode** (rules deny direct client access; see Section 7.4). Pick one region and record it in the README.
- [ ] **Cloud Messaging (FCM)**: enabled by default. For iOS, upload the **APNs authentication key** (.p8) in Project settings → Cloud Messaging.
- [ ] **Register apps** in Firebase: Android (package name agreed by the team, e.g. `com.playerszwz.app`) and iOS (bundle ID). Add the **SHA-1 and SHA-256 debug fingerprints of every developer machine** to the Android app (each teammate's `debug.keystore` differs).
- [ ] Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS). **Do not commit them to a public repo** (see Section 6).
- [ ] **Service account key** for the Flask backend: Project settings → Service accounts → *Generate new private key*. Store it as a secret file, never in Git.
- [ ] Install the **Firebase CLI** (`npm i -g firebase-tools`) and run `firebase login`; used to deploy Firestore rules and indexes from `infra/firebase/`.

### 1.3 Geoapify maps and location APIs

| API | Used for |
|-----|----------|
| **Geoapify Map Tiles API** | Map tiles displayed in the Flutter map on Android and iOS |
| **Geoapify Places API** | Arena/venue search by category, location, or radius |
| **Geoapify Geocoding, Autocomplete, and Reverse Geocoding APIs** | Convert a manual area/address to coordinates, suggest address matches, and resolve coordinates to a readable area |

> **Provider change — 22 October 2026:** Google Maps Platform has been removed because its billing/card setup was not a fit for this FYP budget. Geoapify is the selected provider. Its Free plan currently lists 3,000 credits/day and up to 5 requests/second; map tiles and API operations consume credits, and free-plan use requires Geoapify and data-source attribution. Recheck current limits and attribution requirements before release.

Setup notes:
- Create one Geoapify project/API key and configure it for the mobile map, Places, and geocoding requests. The key is present in app requests, so keep it out of source control and monitor usage and allowed API limits.
- Display Geoapify and required data-source attribution with the map, including on both platforms.
- Distances in the first release should be computed with the **Haversine formula** on the backend; we do **not** need a paid routing or distance-matrix service.

### 1.4 Developer tooling

| Tool | Version / note | Who |
|------|----------------|-----|
| Git | any recent | All |
| Flutter SDK (stable) + Dart | Pin one version for the team in `apps/mobile/README.md` (consider FVM) | All |
| Android Studio + Android SDK, one emulator and ideally one physical Android phone | Android is the primary acceptance target (SRS 4.4) | All |
| Xcode + CocoaPods | **macOS only**; needed to build/check iOS | Whoever has a Mac |
| Python 3.11+ and `venv` | Flask API | Waleed, Hassan |
| Flask, `firebase-admin`, `python-dotenv`, `pytest`, `flask-cors`, `marshmallow` or `pydantic` (validation), `gunicorn` (deploy), `scikit-learn` (optional, later) | Backend dependencies; list in `services/api/requirements.txt` | Backend |
| Node.js (for Firebase CLI) | LTS | Whoever deploys rules |
| Postman or Bruno | API testing; keep the collection in `docs/api/` | All |
| ngrok or a deployed dev URL | Let a physical phone reach a local Flask server (Android emulator can use `10.0.2.2`) | Frontend |

### 1.5 Existing local work to bring into the repo (Sprint 1, first task)

- [ ] Flutter **GPS tracker PoC** → `prototypes/gps-tracker/`
- [ ] Flutter **UI prototype** → `prototypes/ui-prototype/`
- [ ] Existing **Flask backend code** → audit, then move into `services/api/`
- [ ] SRS and SDS PDFs → `docs/phase-01/`, `docs/phase-02/`

---

## 2. Jira sprint map

Sprint names, dates and goals follow the SCRUM board (checked 15 Oct 2026).

| # | Jira sprint | Dates | State | Focus |
|---|-------------|-------|-------|-------|
| 1 | `S1 - Requirements & SRS` | 4–17 May 2026 | Completed | Phase 1 requirements baseline |
| 2 | `S2 - SDS & Design` | 18–31 May 2026 | Completed | Phase 2 design |
| 3 | `S3 - GPS Tracker PoC` | 1–14 Jun 2026 | Completed | Live GPS + map proof of concept |
| 4 | `S4 - UI Prototype` | 15–28 Jun 2026 | Completed | Interactive Flutter UI demo |
| 5 | **`Sprint 1 - Integration`** | **15–29 Oct 2026** | **Active** | Connect screens ↔ APIs, auth, profile, map baseline |
| 6 | `Sprint 2 - Events` | 29 Oct–12 Nov 2026 | Future | Event discovery + join flow |
| 7 | `Sprint 3 - Arenas` | 12–26 Nov 2026 | Future | Arenas, bookings, feedback, moderation |
| 8 | `Sprint 4 - QA & Demo` | 26 Nov–10 Dec 2026 | Future | Recommendations, notifications, QA, demo |

> The Jira sprint dates overlap on the boundary days (29 Oct, 12 Nov, 26 Nov). Treat each boundary day as the previous sprint's review and the next sprint's planning.

**Terminology:** the SDS calls them **games**; the Jira plan calls them **events**. They are the same thing. In code and API use `game`/`games` (matching the SDS schema); in the UI copy, "Game" or "Event" is a product decision to settle once.

---

## 3. Product scope and roles

PlayersZWZ helps people find nearby sports games and players, organize matches, request arena bookings, and receive updates.

| Role | `users.role` value | Capabilities |
|------|--------------------|--------------|
| Player | `player` | Maintain sport preferences, find games, request to join, rate/report after a game |
| Organizer | `organizer` | Everything a player can do, plus create games, approve/reject join requests, request arena bookings. (In the SDS the Game Organizer *inherits* from Player. **[Proposed]** model this as a player who owns a game rather than a separate account type, so a user does not need to switch roles.) |
| Arena manager | `arena_manager` | Manage arena info and respond to booking requests. **Open decision D-01**: first release may use admin approval instead |
| Administrator | `admin` | Review reports, warn/suspend/clear accounts, audit trail |

**Release focus:** match discovery and game joining are the centre of the product. Arena booking, moderation and recommendations build on that.

---

## 4. Architecture and tech stack

Layered client–server system (SDS §1).

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Android first, iOS checked alongside) |
| API | Flask REST API, organised by feature; versioned under `/api/v1` **[Proposed]** (SDS lists `/api/...` without version; see Section 8 note) |
| Auth | Firebase Authentication; the API **validates Firebase ID tokens** and enforces roles |
| Database | Cloud Firestore, accessed **only through the backend** for product operations |
| Maps/location | Geoapify map tiles, Places, and geocoding; manual-area entry when permission is denied |
| Notifications | Firebase Cloud Messaging + Firestore-backed in-app notifications |
| Recommendations | Explainable rules first (sport, distance, availability, activity, reliability); ML only if real usage history exists |
| CI | GitHub Actions |

**Rule:** the mobile app calls the Flask API for every protected business operation. The API alone enforces capacity limits, duplicate-join prevention, booking conflicts and admin permissions. The app never writes product data straight to Firestore.

**Request flow:** Flutter signs in with the Firebase SDK → gets an **ID token** → sends `Authorization: Bearer <token>` with every API call → Flask middleware verifies the token with `firebase-admin`, loads the user's role from `users`, and attaches both to the request.

---

## 5. Repository structure

Keep project documents and the existing prototypes. Add the integrated product in separate folders so production code is never confused with demos.

```text
PlayersZWZ/
├── README.md
├── IMPLEMENTATION_PLAN.md            # this file
├── docs/
│   ├── proposal/
│   ├── phase-01/                     # SRS
│   ├── phase-02/                     # SDS
│   └── api/                          # Postman/Bruno collection, OpenAPI file [Proposed]
├── apps/
│   └── mobile/                       # Main Flutter application
│       ├── lib/
│       │   ├── app/                  # Startup, routing, theme
│       │   ├── core/                 # API client, config, errors, location
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
│   └── api/                          # Main Flask API
│       ├── app/
│       │   ├── api/                  # Versioned route blueprints
│       │   ├── auth/
│       │   ├── profiles/
│       │   ├── discovery/
│       │   ├── games/
│       │   ├── bookings/
│       │   ├── recommendations/
│       │   ├── feedback/
│       │   ├── notifications/
│       │   └── admin/
│       ├── tests/
│       ├── requirements.txt
│       └── .env.example
├── prototypes/
│   ├── gps-tracker/                  # Existing GPS proof of concept
│   └── ui-prototype/                 # Existing UI demonstration
├── infra/
│   ├── firebase/                     # firestore.rules, firestore.indexes.json
│   └── deployment/                   # Hosting config
└── .github/
    └── workflows/                    # Automated checks
```

Conventions:
- Each mobile feature keeps its screens, API/data handling and feature rules together.
- Each backend feature package has `routes.py` (HTTP only), `service.py` (business rules) and `repository.py` (Firestore access). The SDS calls this the *Data Access Layer*; keep Firestore queries only in repositories.
- `prototypes/` is read-only reference. Do not build production features there.

---

## 6. Environment configuration and secrets

**Never commit:** `google-services.json`, `GoogleService-Info.plist`, the Firebase service-account JSON, `.env` files, or any API key. Add them to `.gitignore` in the first commit. If a secret is ever pushed, **rotate it**; deleting the commit is not enough.

Commit **`.env.example`** files with placeholder values so teammates know what to create.

### Backend (`services/api/.env.example`)

```dotenv
FLASK_ENV=development
PORT=5000
# Path to the Firebase service-account JSON (kept out of Git)
GOOGLE_APPLICATION_CREDENTIALS=./secrets/firebase-service-account.json
FIREBASE_PROJECT_ID=playerszwz-dev
# Server-side Google key (Geocoding/Places) if the backend calls them
# Geoapify API key (only needed if the backend calls Geoapify; keep real values out of Git)
GEOAPIFY_API_KEY=replace-me
# Comma-separated origins allowed by CORS (web admin, if any)
CORS_ORIGINS=http://localhost:3000
# Default search radius and limits
DEFAULT_RADIUS_KM=10
MAX_RADIUS_KM=50
```

### Mobile

- Geoapify API key: inject with `--dart-define=GEOAPIFY_API_KEY=...`; do not hard-code it in Dart source. The mobile key is visible in client requests, so monitor quota and configure available provider restrictions.
- The Flutter map widget loads Geoapify Map Tiles; location search and manual-area lookup use Geoapify Places/Geocoding endpoints.
- API base URL: use `--dart-define=API_BASE_URL=...` so dev/staging/demo builds do not need code changes.
- Android emulator reaches the host machine at `http://10.0.2.2:5000`; a physical phone needs the host's LAN IP or an ngrok/deployed URL.

---

## 7. Data model (Firestore)

The SDS schema (§5.2) is the starting point. Refinements for implementation are marked **[Proposed]**.

### 7.1 Collections

| Collection | Key fields (SDS) | Added for implementation **[Proposed]** |
|------------|------------------|------------------------------------------|
| `users` | `user_id` (Firebase UID), `name`, `email`, `role`, `city`, `status` (`active`/`warned`/`suspended`), `created_at` | `fcm_tokens` (array) for push |
| `profiles` | `profile_id`, `user_id`, `sports[]`, `availability`, `radius_km`, `bio`, `location` (GeoPoint), `reliability_score` | `geohash` (string) for radius queries; `manual_area` (string) for the permission-denied path; `location_source` (`gps`/`manual`) |
| `games` | `game_id`, `organizer_id`, `sport`, `start_time`, `location` (GeoPoint/string), `required_players`, `status` (`open`/`full`/`completed`/`cancelled`) | `geohash`; `approved_count` (kept in sync transactionally); `venue_text`; `notes`; `arena_booking_id` (optional) |
| `game_participants` | `participant_id`, `game_id`, `user_id`, `request_status` (`pending`/`approved`/`rejected`/`cancelled`), `joined_at` | Use a **deterministic document ID `{game_id}_{user_id}`** so duplicate join requests are impossible by construction |
| `arenas` | `arena_id`, `manager_id`, `name`, `sports[]`, `address`, `location`, `slot_status` | `geohash`; consider a `slots` subcollection instead of one big map so slot conflicts can be checked transactionally |
| `booking_requests` | `booking_id`, `arena_id`, `game_id` (optional), `requested_by`, `slot_time`, `status` (`pending`/`approved`/`rejected`/`cancelled`), `manager_notes` | `slot_key` (`{arena_id}_{start_time}`) used to detect conflicts |
| `ratings_reports` | `rating_id`, `game_id`, `from_user_id`, `to_user_id`, `rating` (1–5), `report_reason`, `status` (`submitted`/`under_review`/`resolved`) | Deterministic ID `{game_id}_{from}_{to}` to block duplicate feedback; `type` (`rating`/`report`/`no_show`) |
| `notifications` | `notification_id`, `user_id`, `type` (join/booking/reminder/moderation), `message`, `is_read`, `created_at` | `payload` (deep-link data), e.g. `{game_id, request_id}` |
| `admin_actions` | `action_id`, `admin_id`, `target_user_id`, `action_type` (`warn`/`suspend`/`clear`), `notes`, `created_at` | `report_id` link |

### 7.2 State machines (enforced only in the API)

```text
Join request:  pending ──approve──▶ approved
                  │ └──reject───▶ rejected
                  └──cancel (by player)──▶ cancelled
               approved ──cancel (by player/organizer)──▶ cancelled

Booking:       pending ──approve──▶ approved
                  │ └──reject───▶ rejected
                  └──cancel (by requester)──▶ cancelled
               approved ──cancel──▶ cancelled

Game:          open ──(approved_count == required_players)──▶ full
               full ──(an approved player cancels)──▶ open
               open/full ──organizer cancels──▶ cancelled
               open/full ──after start_time + organizer/system marks──▶ completed
```

Rules to implement (use Firestore **transactions**):
- Approving a join request: re-read the game, reject if `approved_count >= required_players` ("Game is full"), increment `approved_count`, set game `full` if reached.
- Creating a booking: reject if another `pending` **or** `approved` booking exists for the same `slot_key` ("Slot unavailable").
- Only the game's organizer can approve/reject its requests; only a requester can cancel their own request/booking.
- Pending and approved slots are **never shown as free**. Pending is displayed as "requested", not "booked".

### 7.3 Indexes

Define composite indexes in `infra/firebase/firestore.indexes.json` as queries are written (for example `games`: `status` + `sport` + `start_time`; `game_participants`: `game_id` + `request_status`). Query only what you index; paginate every list.

### 7.4 Security rules

Because all product reads/writes go through the API (which uses the Admin SDK and bypasses rules), set `infra/firebase/firestore.rules` to **deny all direct client access**. Deploy with `firebase deploy --only firestore:rules,firestore:indexes`.

### 7.5 Nearby search approach

Store a `geohash` on profiles, games and arenas. For a search: compute geohash prefixes covering the radius bounding box, query by those prefixes, then **filter exactly with Haversine** and sort by distance. This matches the SDS's "geohash/radius filters". If the query volume at academic scale is small, a bounding-box query on lat/lng followed by Haversine is an acceptable simpler start.

---

## 8. API reference

Base URL: `{API_BASE_URL}/api/v1` **[Proposed: add `/v1`; the SDS lists `/api/...`]**. All endpoints except health check require `Authorization: Bearer <Firebase ID token>`.

**Standard error body [Proposed]:**

```json
{ "error": { "code": "GAME_FULL", "message": "This game is already full." } }
```

Common codes: `400 VALIDATION_ERROR`, `401 UNAUTHENTICATED`, `403 FORBIDDEN`, `404 NOT_FOUND`, `409 CONFLICT` (duplicate request, slot unavailable, game full), `429 RATE_LIMITED`.

### 8.1 Endpoints from the SDS (§6)

| Sprint | Endpoint | Method | Input | Output | Auth |
|--------|----------|--------|-------|--------|------|
| 1 | `/auth/register` | POST | name, email, password, city, favorite_sport | user_id, profile_id, token/status | none* |
| 1 | `/auth/login` | POST | email, password | token, user role | none* |
| 1 | `/profile/{userId}` | GET | token | profile, preferences, reliability score | user |
| 1 | `/profile/{userId}` | PUT | sports, bio, availability, radius, location | updated profile | owner |
| 2 | `/discovery/players` | GET | sport, radius_km, location / manual_area | compatible players | user |
| 2 | `/games` | POST | sport, date_time, location, required_players | created game | user |
| 2 | `/games/open` | GET | sport, radius_km, location | open games | user |
| 2 | `/games/{gameId}/join` | POST | token | join_request_id, pending/approved | user |
| 2 | `/join-requests/{requestId}` | PATCH | approve/reject | updated request + participant list | organizer of that game |
| 3 | `/arenas` | GET | sport, location, radius | arenas with slots | user |
| 3 | `/bookings` | POST | arena_id, game_id, slot_time, notes | booking (Pending) | organizer |
| 3 | `/bookings/{bookingId}/status` | PATCH | approved/rejected, manager notes | booking + notifications | arena manager / admin |
| 3 | `/ratings` | POST | game_id, to_user_id, rating/report | saved feedback, trust update | participant |
| 3 | `/admin/reports` | GET | admin token | pending reports, affected users | admin |
| 3 | `/admin/actions` | POST | report_id, action_type, notes | logged decision | admin |
| 4 | `/recommendations` | GET | token, location/sport filters | ranked games and players | user |
| 4 | `/notifications` | GET | token | in-app notification list | user |

\* **Design note on register/login.** With Firebase Authentication, the Flutter app normally signs users up and in **directly through the Firebase SDK** (the password never needs to pass through Flask). **[Proposed]** replace `register`/`login` with:
- `POST /auth/session`: called right after Firebase sign-up/sign-in; the API verifies the ID token and **creates the `users` + `profiles` records on first call** (name, city, favorite_sport in the body), returning user, profile and role.
- `GET /me`: returns the current user, profile and role.

If the team prefers to keep `/auth/register` and `/auth/login` as written in the SDS, they must proxy to Firebase's REST API. This is more work and less secure. Decide under D-02.

### 8.2 Endpoints missing from the SDS that the plan needs **[Proposed]**

| Sprint | Endpoint | Method | Purpose |
|--------|----------|--------|---------|
| 1 | `/health` | GET | Unauthenticated liveness check for deploy and CI |
| 1 | `/me/fcm-token` | POST/DELETE | Register/remove a device token for push |
| 2 | `/games/{gameId}` | GET | Game details: organizer, open spots, the caller's participation status |
| 2 | `/games/{gameId}` | PATCH/DELETE | Organizer edits or cancels a game |
| 2 | `/games/{gameId}/join` | DELETE | Player cancels their own request/participation |
| 2 | `/games/{gameId}/requests` | GET | Organizer lists pending/approved requests for a game |
| 2 | `/me/games` | GET | "Activity" tab: hosted / joined / history |
| 3 | `/arenas/{arenaId}` | GET | Arena details with slot availability for a date |
| 3 | `/bookings/{bookingId}` | GET/DELETE | View status; requester cancels |
| 3 | `/me/bookings` | GET | Requester's bookings |
| 3 | `/admin/bookings` | GET | If admin approves bookings (D-01) |
| 3 | `/ratings/{ratingId}/dispute` | POST | Dispute window required by risk R-04 / fairness requirement |
| 4 | `/notifications/{id}/read` | PATCH | Mark as read |
| 4 | `/notifications/read-all` | POST | Mark all as read |

### 8.3 Third-party APIs consumed

| Service | Called from | Purpose |
|---------|-------------|---------|
| Firebase Authentication | App (SDK) and API (Admin SDK verify) | Sign-in, ID-token verification |
| Cloud Firestore | API only | Persistence |
| Firebase Cloud Messaging | API (Admin SDK `messaging.send`) | Push notifications |
| Geoapify Map Tiles, Places, Geocoding, and Reverse Geocoding APIs | Flutter app | Map tiles, venue search, address lookup, and readable locations |
| Places / Geocoding | App and/or API | Manual-area lookup, address ↔ coordinates |

---

## 9. Sprint-by-sprint implementation

Owners follow the roles in the SRS/SDS and are **suggestions** the team can change in sprint planning. Waleed: app architecture, backend integration, coordination. Afaq: frontend, maps/location, UI flows. Hassan: recommendation module, testing, documentation, QA. Story IDs refer to the SRS.

### Sprint 1 — Integration (15–29 Oct 2026, active)

The map baseline uses Geoapify Map Tiles, Places, and Geocoding instead of Google Maps Platform. See Section 1.3 for the provider-change note, current quota guidance, and attribution requirements.

**Goal:** connect the existing Flutter screens, current APIs, authentication/profile, and establish the personalised map baseline.

**Stories touched:** US-01, US-02, US-03 (SRS Sprint 1, 9 points) plus the map baseline from the GPS PoC.

| # | Task | Suggested owner |
|---|------|-----------------|
| 1.1 | **Complete prerequisites P-01 to P-05** and the Firebase/Maps checklists in Section 1 | Waleed |
| 1.2 | **Audit** the local Flutter app and Flask code. Produce `docs/audit.md` classifying every screen/endpoint as *reusable*, *incomplete* or *still needed* | Waleed (backend), Afaq (Flutter) |
| 1.3 | Create the repo layout from Section 5; move the app to `apps/mobile/`, API to `services/api/`, PoCs to `prototypes/` | Waleed |
| 1.4 | Backend skeleton: app factory, blueprints, config loader, `/health`, standard error handler, Firebase Admin init | Waleed |
| 1.5 | **Auth middleware:** verify ID token, load user + role, `@require_role(...)` decorator | Waleed |
| 1.6 | `POST /auth/session` (or register/login per D-02), `GET /me`; create `users` + `profiles` on first sign-in | Waleed |
| 1.7 | Flutter: Firebase init, sign-up/login/logout screens wired to Firebase, token attached to every API call by a central API client (`core/`) | Afaq |
| 1.8 | Flutter API client: base URL via `--dart-define`, request/response models, loading/error/retry states | Afaq |
| 1.9 | Profile: `GET/PUT /profile/{userId}`; screen for sports, availability, radius, bio, location | Afaq + Waleed |
| 1.10 | Location: request permission; on denial show **manual area entry** (Geoapify Geocoding/Autocomplete) and still let the user continue (SRS R-01, TD-04) | Afaq |
| 1.11 | **Map baseline:** port tracker/map code from the GPS PoC into `features/discovery/`; show the user position over Geoapify map tiles and a placeholder layer for games | Afaq |
| 1.12 | Firestore rules (deny direct client access) and first indexes in `infra/firebase/` | Waleed |
| 1.13 | CI: GitHub Actions running `flutter analyze` + `flutter test` and `pytest` + `ruff`/`flake8` on every PR | Hassan |
| 1.14 | Secrets hygiene: `.gitignore`, `.env.example`, secret scan, short README setup for each app | Hassan |
| 1.15 | First deploy of the API to the chosen host so physical phones can reach it | Waleed |

**Exit criteria (sprint outcome):** a signed-in user can save preferences and location; the integrated app talks to the backend and shows the map foundation; the existing code is audited and classified; CI is green; no secrets in Git.

### Sprint 2 — Events (29 Oct–12 Nov 2026)

**Goal:** personalised map discovery and event participation.

**Stories:** US-05, US-06, US-07 and the discovery part of US-04 (SRS Sprint 2: US-04 to US-07, 14 points). **Event discovery is the primary map experience; player discovery (US-04) is secondary**; see D-04.

| # | Task | Suggested owner |
|---|------|-----------------|
| 2.1 | `POST /games` with validation (sport, time in the future, location, `required_players` ≥ 1) and `geohash` | Waleed |
| 2.2 | `GET /games/open` with sport, radius, optional time-window and availability filters; distance-sorted; paginated | Waleed |
| 2.3 | `GET /games/{id}` with open spots and the caller's participation status | Waleed |
| 2.4 | `POST /games/{id}/join` with the **deterministic participant ID** (duplicate prevention) and capacity pre-check; returns `409` with clear codes | Waleed |
| 2.5 | `PATCH /join-requests/{id}`: organizer-only; **transactional** approve with capacity check; updates `approved_count` and game `full` status | Waleed |
| 2.6 | Cancel join request / participation; reopen a `full` game when an approved player cancels | Waleed |
| 2.7 | Flutter: **nearby map + list** of games with markers; sport and distance filters at the top (SDS wireframe rule); time filter | Afaq |
| 2.8 | Flutter: **Game details** screen (sport, time, location, organizer, open spots, my status) with Join / Cancel button | Afaq |
| 2.9 | Flutter: **Create game** form (few fields, per Usability requirement) | Afaq |
| 2.10 | Flutter: **Activity** tab: Hosted / Joined / History; **Join requests** review sheet with Approve/Reject | Afaq |
| 2.11 | Empty, permission, network and **full-game** states on every discovery/join screen | Afaq |
| 2.12 | Player discovery list (`GET /discovery/players`) if time remains | Afaq + Waleed |
| 2.13 | Tests: TD-05, TD-06, TD-07 (backend unit/integration) and widget tests for the join button states | Hassan |

**Exit criteria:** a user can find a relevant nearby game, open it and request to join; the organizer can approve/reject without ever exceeding capacity; duplicate requests are impossible.

### Sprint 3 — Arenas (12–26 Nov 2026)

**Goal:** nearby arena discovery, booking and trust flows.

**Stories:** US-08, US-09, US-12, US-14 (the Jira plan moves feedback and moderation here; the SRS had them in Sprint 4. US-13 notifications partly start here for booking updates).

| # | Task | Suggested owner |
|---|------|-----------------|
| 3.1 | Seed arena data (script in `services/api/scripts/seed_arenas.py`) with realistic Lahore arenas; this unblocks UI work | Hassan |
| 3.2 | `GET /arenas`, `GET /arenas/{id}` with sport/location filters and slot availability for a date | Waleed |
| 3.3 | `POST /bookings`: stored as `pending`; **slot-conflict check** against pending and approved (TD-08); link optional `game_id` | Waleed |
| 3.4 | `PATCH /bookings/{id}/status`: approve/reject with notes (arena manager or admin per D-01); `GET/DELETE` for requester | Waleed |
| 3.5 | Booking update notifications to requester and approver (in-app records first; FCM in Sprint 4) | Waleed |
| 3.6 | Flutter: **Arena list/map**, arena details, slot picker, **Request Booking**, **Booking status** screen | Afaq |
| 3.7 | UI shows `pending` as *Requested*, never as *Booked*, until approved (risk R-03) | Afaq |
| 3.8 | `POST /ratings`: only participants of a completed game, once per participant/game (TD-11); store rating or report | Hassan |
| 3.9 | **Reliability rules v1:** score changes only from *confirmed* no-shows, rating averages and repeated reports; every change logged for audit (SRS 4.1, R-04) | Hassan |
| 3.10 | Dispute window for ratings/reports (`/ratings/{id}/dispute`) | Hassan |
| 3.11 | Admin: `GET /admin/reports`, `POST /admin/actions` (warn/suspend/clear) writing to `admin_actions`; suspended users blocked at the auth middleware | Waleed + Hassan |
| 3.12 | Flutter: post-game **Rate/Report** screen; **Admin** screens (reports list, action, audit log) | Afaq |
| 3.13 | Tests: TD-08, TD-11, TD-12 | Hassan |

**Exit criteria:** users can find arenas, request and track a slot, and submit post-game feedback; booking conflicts and moderation decisions are handled explicitly and auditable.

### Sprint 4 — QA & Demo (26 Nov–10 Dec 2026)

**Goal:** recommendations, notifications, cross-platform QA and a jury-ready demo.

**Stories:** US-10, US-11, US-13, plus QA.

| # | Task | Suggested owner |
|---|------|-----------------|
| 4.1 | `GET /recommendations` per Section 10: rule-based fallback first (TD-09), then history/reliability ranking (TD-10); return **explanation tags** | Hassan |
| 4.2 | Flutter: recommendation feed with tags such as "Nearby", "Your sport", "Reliable host" | Afaq |
| 4.3 | Notification service: write in-app records and send **FCM** for the events in Section 11; device-token registration; retry on failure | Waleed |
| 4.4 | Flutter: FCM setup (Android + iOS), foreground/background handling, in-app notification list, deep-links | Afaq |
| 4.5 | Reminders for upcoming games (scheduled job: Cloud Scheduler / simple cron endpoint) | Waleed |
| 4.6 | Run all TD-01 … TD-14 test scenarios; regression-check auth, manual location, discovery, join approval, booking conflicts, feedback, moderation, network failures | Hassan |
| 4.7 | Android + iOS pass on the main flows; fix usability and cross-platform defects | All |
| 4.8 | **Measure** performance targets (Section 12.2) and record results | Hassan |
| 4.9 | Demo data seed script, rehearsed presentation flow, setup notes, final demo build; release-criteria checklist (SRS §5.3) | All |
| 4.10 | Update IV&V appendices with implementation defects and results | Hassan |

**Exit criteria:** the core app is integrated; test results and known limitations are documented; the demo runs reliably end to end.

---

## 10. Recommendation logic

**Phase A, rule-based (new users, US-10):** filter games to the user's preferred sports within their radius and with open spots; sort by distance, then start time.

**Phase B, weighted score (US-11):** for each candidate game:

```text
score = w1·sport_match + w2·proximity + w3·availability_fit + w4·activity + w5·host_reliability
```

Each term is normalised to 0–1. **[Proposed]** starting weights (tune by testing, record in code as constants): sport 0.30, proximity 0.25, availability 0.15, activity/history 0.15, reliability 0.15. The profile toggles in the prototype ("Prioritize Proximity", "Strict Reliability Match") map directly to weight changes or hard filters.

Requirements:
- Always return **why** a result ranked (explanation tags).
- Targets: rule-based ≤ 3 s, history-based ≤ 6 s on prototype data (SRS 4.2).
- Keep the ranker a separate module so it can be swapped for a trained model later; ML is deferred.

---

## 11. Notification matrix

| Event | Recipient | In-app | Push | Sprint |
|-------|-----------|:------:|:----:|:------:|
| Join request received | Organizer | ✔ | ✔ | 2 (in-app) / 4 (push) |
| Request approved / rejected | Player | ✔ | ✔ | 2 / 4 |
| Game cancelled or changed | Approved players | ✔ | ✔ | 2 / 4 |
| Booking requested | Arena manager / admin | ✔ | ✔ | 3 / 4 |
| Booking approved / rejected / cancelled | Requester | ✔ | ✔ | 3 / 4 |
| Game reminder (e.g. 2 h before) | Organizer + approved players | ✔ | ✔ | 4 |
| Moderation outcome (warn/suspend) | Affected user | ✔ | ✔ | 3 / 4 |

In-app records are always written first (source of truth). Push is best-effort with a logged retry.

---

## 12. Test plan

### 12.1 Mapping to the SDS test design

| ID | Scenario | Sprint | Level |
|----|----------|:------:|-------|
| TD-01 | Valid sign-up creates account + profile | 1 | API + manual |
| TD-02 | Invalid login shows readable error, no crash | 1 | Widget + manual |
| TD-03 | Profile edits persist and affect discovery | 1–2 | API + manual |
| TD-04 | Location denied → manual area works | 1 | Manual (device) |
| TD-05 | Valid game created and visible nearby | 2 | API |
| TD-06 | Duplicate join blocked ("Request Already Sent") | 2 | API |
| TD-07 | Approval within capacity updates list + notifies | 2 | API |
| TD-08 | Booking conflict on pending/approved slot rejected | 3 | API |
| TD-09 | New-user fallback recommendations | 4 | API |
| TD-10 | History-based ranking order | 4 | API |
| TD-11 | Duplicate rating/report accepted only once | 3 | API |
| TD-12 | Admin warn/suspend logged and status updated | 3 | API |
| TD-13 | Network drop shows message, keeps local state | 4 | Manual |
| TD-14 | 50 concurrent users, no noticeable slowdown | 4 | Load test |

**Additional cases to add [Proposed]:** approving when the game is already full; two organizers/approvals racing for the last spot; suspended user blocked; expired/invalid ID token → 401; non-organizer attempting to approve → 403; cancelling an approved request reopens a full game.

### 12.2 Performance targets (measure, do not assume)

- Dashboard load < 3 s on normal Wi-Fi.
- Nearby results (first page) < 5 s.
- Recommendations: fallback ≤ 3 s, history-based ≤ 6 s.
- ~50 concurrent academic test users without noticeable slowdown. Use `locust` or `k6` against the deployed dev API.

---

## 13. Git workflow and Definition of Done

**Branches:** `main` (demo-ready), `develop` (integration), `feature/SCRUM-<n>-short-name`, `fix/SCRUM-<n>-short-name`.
**Commits:** `SCRUM-12: add join-request capacity check`. **PRs:** target `develop`, link the Jira issue, at least one teammate review, CI green. Merge `develop` → `main` at sprint end.

A feature is **done** when:

- [ ] Its acceptance criteria from the SRS/SDS are met.
- [ ] The happy path and important edge cases work (duplicates, unavailable slots, full games).
- [ ] Loading, empty, permission-denied, offline and error states are understandable.
- [ ] API authorization and role checks protect the operation.
- [ ] Automated checks pass **and** the feature was exercised on a device or emulator.
- [ ] Setup or usage notes are in the README/feature docs.
- [ ] The Jira issue is linked via branch, commit and PR.

---

## 14. Scope deferred

Per SDS §12 and risk R-06, **not** in the first release: machine-learning recommendations, payments (including the Cash/Online and entry-fee fields in the prototype), tournaments, social login (Google button in the prototype), badges and team groups, a full arena-manager portal, web admin dashboard, international deployment. Revisit only after the core flows are stable and tested.

---

## 15. Open decisions and document inconsistencies

### Decisions to confirm (Sprint 1 planning)

| ID | Decision | Default if undecided |
|----|----------|----------------------|
| D-01 | Do arena managers sign in and manage slots in the first release, or does an admin approve bookings? | Admin approves (smaller scope) |
| D-02 | Auth endpoints: Firebase SDK + `/auth/session` + `/me`, or SDS-style `/auth/register` and `/auth/login`? | Firebase SDK + `/auth/session` |
| D-03 | Release blocker platform: Android only, or Android and iOS both? (SRS says Android is primary) | Android must pass; iOS checked |
| D-04 | Player discovery (US-04): in or out of the first release? The Jira plan makes games the main map item | Games first; players if time remains |
| D-05 | Which parts of the local Flutter app and backend already work? | Resolved by the Sprint 1 audit |
| D-06 | Is "Organizer" a role or just a player who owns a game? | Player who owns a game |

### Inconsistencies found in the source documents (fix in a later revision)

1. **Scrum Master:** the SRS cover says *Afaq Ul Islam*; the SRS Scrum Roles table (§2) says *Waleed Abid*. The SDS says Afaq.
2. **SRS burndown table (§5.4):** Week 0 "Planned Remaining SP" reads `8` where the chart and total (80) indicate `80`.
3. **Sprint mapping differs** between the SRS (Sprint 2 = player discovery, Sprint 4 = recommendations + feedback + moderation) and the Jira plan (Sprint 2 = events, Sprint 3 = arenas + feedback + moderation). This plan follows **Jira**.
4. **SDS §13 Revised Project Plan** lists only two prototype sprints; Jira has four.
5. **UI prototype vs scope:** it shows Google sign-in, entry fee and Cash/Online payment, which are deferred features.
6. **SDS API gaps:** no endpoints for game details, cancel, my-games, FCM tokens, notification read state or rating disputes (added in Section 8.2).
7. **Register/login via Flask** conflicts with "Firebase Authentication handles credentials" (see D-02).
8. **SRS Appendix** misspells the product consistently as PLAYERSZWZ while some UI copy reads *PlayersZWZ*; pick one spelling for the app store name and README.

---

## 16. Risks

| ID | Risk | Mitigation in this plan |
|----|------|-------------------------|
| R-01 | Location permission denied | Manual area entry is a Sprint 1 deliverable and test TD-04 |
| R-02 | New users have no history | Rule-based fallback ships before ranking (Sprint 4, Phase A) |
| R-03 | Arena slot data inaccurate | Request-based booking; pending is never shown as booked |
| R-04 | Unfair ratings damage reliability | Duplicate prevention, dispute window, only confirmed no-shows count |
| R-05 | Backend/Firebase integration delays | Sprint 1 is fully dedicated to integration; mock-data fallback for UI |
| R-06 | Scope creep | Section 14 deferral list |
| R-07 | Maps/FCM limits | Budget alerts and quotas, retry logic, manual fallback |
| R-08 | Workload imbalance | Named owners per task; weekly check-in |
| **New** | **Secrets leaked to Git** | Section 6 rules, CI secret scan, rotate on leak |
| **New** | **Geoapify free-plan limits and attribution** | Track daily credit and request limits; display required provider/data-source attribution (Section 1.3) |
| **New** | **Late iOS push discovery** (needs APNs/paid account) | Decide D-03 and P-06 in Sprint 1 |
| **New** | **Race conditions on last spot / last slot** | Firestore transactions + deterministic document IDs |

---

## 17. Demo flow

Build toward this order first; it shows the core value before arenas, moderation and advanced recommendations.

1. Register and choose preferred sports.
2. Set current or manual location.
3. Find nearby games on the map or list.
4. Open a game and request to join.
5. Organizer approves the request.
6. Player receives an in-app or push notification.

Then extend the demo with: request an arena booking → approval → post-game rating → admin moderation → recommendation feed.

---

*Source documents: `PlayersZWZ - Phase 01.pdf` (SRS v1.2) and `PlayersZWZ - Phase - 02.pdf` (SDS v2.0), both in `docs/`.*
