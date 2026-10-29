# PlayersZWZ — Current Progress

**Updated:** 29 October 2026  
**Workspace:** local development only. No Git commits, pushes, or syncs have been made.

## Working agreement

- Before code changes, provide a short checklist naming the paths and purpose, then complete the approved local step autonomously, following `AGENTS.md`.
- Codex implements local coding and verification. Afaq manages accounts, credentials, and physical-device testing with step-by-step guidance.
- Do not perform Git work until Afaq explicitly says to begin.
- `PLAN.md` is the implementation plan and must not be edited as part of progress updates.

## Completed

- Created the main Flutter app at `apps/mobile/` for Android and iOS, using `com.playerszwz.app` on both platforms.
- Firebase project configured with Email/Password, Google sign-in, Cloud Firestore in `asia-south2`, and Cloud Messaging.
- Flutter sign-up/sign-in and Google sign-in work on the iPhone. Firebase Authentication shows the created account.
- Flask dependencies are installed in `services/api/.venv`; the local API starts successfully.
- `GET http://127.0.0.1:5000/health` returns `{"status":"ok","service":"playerszwz-api"}`. Visiting `/` returns 404 as expected because no root page is defined.
- Backend `.env` points to project `playerszwz` and `./secrets/firebase-service-account.json`. The service-account file is stored under the ignored `services/api/secrets/` folder; never paste or commit its contents.
- Backend Firebase Admin helper and Firebase token middleware have been added at `services/api/app/firebase.py` and `services/api/app/auth/middleware.py`.
- `docs/SETUP.md` and `docs/UI_DESIGN_SYSTEM.md` describe the workspace setup and UI references. The previously recorded root `README.md` is absent from the current workspace.
- Confirmed the empty `services/api/app/auth/__init__.py` package marker already exists.
- Added `POST /api/v1/auth/session` and `GET /api/v1/me`, protected by the existing Firebase token middleware.
- Added separate auth route, service, and repository modules. Session setup atomically creates missing `users/{uid}` and `profiles/{uid}` records; repeated sessions preserve existing records and privileges. Default role is server-assigned `player`; email comes from verified token claims. Suspended accounts are checked again inside the transaction.
- Added JSON input validation and consistent setup/database errors. Reliability score starts as `null` until a scoring rule exists.
- Verification: 10 local `unittest` tests passed using mocked Firebase/Firestore access, covering token rejection, input/role injection, account retrieval, suspension, service failures, repeat-session preservation, and missing-profile repair. Actual Firestore commits, concurrent retries, and mobile integration remain unverified.

## Current structure

- `apps/mobile/lib/app/` — app theme, startup routing, and signed-in placeholder.
- `apps/mobile/lib/core/` — shared API client and runtime configuration.
- `apps/mobile/lib/features/auth/` — Flutter authentication screen and Firebase sign-in service.
- `services/api/app/` — Flask app factory, configuration, health endpoint, and Firebase Admin helper.
- `services/api/app/auth/` — backend Firebase authentication middleware. This is separate from Flutter's `features/auth/`.
- `prototypes/` — earlier GPS and UI Flutter projects retained as references.
- `docs/`, `infra/`, and `UI Screens/` — project documentation, infrastructure notes, and supplied UI references.

## Next implementation steps

Onboarding and login/signup UI are implemented with supplied branding/artwork, field validation, loading/error states, and the official Google mark. User confirmed Release typing/swiping are smooth. The latest field typography adjustment still needs eventual device review; launcher icons remain pending. See milestone entries below for visual differences and verification limits.

1. Configure a reachable API address for the mobile app, then verify real sign-in and `users/{uid}` / `profiles/{uid}` persistence at an agreed integration checkpoint. Local session integration is implemented; no live database writes have been performed during this work.
2. Build game creation and nearby-game discovery endpoints, then connect real game markers and sport filters to the implemented Explore map foundation.
3. Review the new launcher icon and remaining UI/device checks on the next agreed installation. User requested local checks rather than a device build after each small change.

## Follow-up notes

- The Firebase Dynamic Links console warning does not affect the current Email/Password or native Google sign-in flows.
- A debug build opened from the iPhone Home Screen shows iOS's debug-only launch notice; Home Screen launching requires a profile/release build. Release-mode installation has not yet been recorded as verified.
- An iOS code-signing/storage problem occurred earlier. Recheck available disk space and signing if another iPhone build fails.
- Generated caches/build files are present locally. Ignore/cleanup rules will be handled later when Git work is authorized.

## Branding assets — 29 October 2026

- User supplied `Artifacts/playerszwz-logo.svg`, Google PNG, and five illustration PNGs; confirmed SF Pro typography and SF Symbols for sport selection. Illustration-to-screen mapping remains to be checked visually.
- Replaced text X/G placeholders with supplied SVG/PNG assets in the mobile app, registered branding assets, and added flutter_svg. Removed the explicit Roboto override so Flutter uses platform typography (SF on iOS). Android typography is not an exact SF Pro match.
- Launcher icons, onboarding implementation, full reference matching, and field/button state refinements remain pending. No device visual verification performed.

## Onboarding implementation — 29 October 2026

- Reread `AGENTS.md`. User approved supplied nearby/arena/matchmaking illustrations despite differences from screenshot artwork. Welcome uses the matching phone-and-pitch illustration.
- Added four pages under `apps/mobile/lib/features/onboarding/` and named illustration assets. Layout follows the 402×874 references; first/last pages expose Google, email signup, and login actions. Swipe or tap the accessible 100×48 indicator to advance.
- Signed-out users enter `WelcomeFlow`; signup/login opens the correct existing form inside the auth gate. Successful Firebase authentication replaces the signed-out flow; Back returns to welcome. No persistent onboarding-seen preference: signed-out launches show welcome.
- Google sign-in prevents duplicate actions, displays loading, handles cancellation quietly, and permits retry after failure. Programmatic page movement uses 250 ms easing and jumps with reduced motion. Small screens and enlarged text scroll vertically.
- Verification: Flutter analysis passed; three widget tests passed for page rendering/actions, pending/error sign-in, and 320×568 at 200% text scale. Inspected all four local SF-font renders at 402×874 in `apps/mobile/test/goldens/`. Golden comparisons are macOS-only, using installed SF typography. These are test renders, not device screenshots.
- Remaining differences: approved replacement artwork has visible dark backgrounds; supplied logo color differs slightly from screenshot lime. Typography and image proportions are close, not claimed pixel-exact. Android uses its platform font. Device performance, swipe feel, and real Google sign-in from onboarding remain unverified.
- Next: review onboarding on the user's iPhone, then login/signup layout and field-state polish. Launcher icons and backend session integration remain pending.

## Device feedback fixes — 29 October 2026

- User confirmed app eventually launches on iPhone, but screenshots exposed scrolling at normal text size and account actions moving with pages. Corrected onboarding to a height-constrained layout with a stationary account footer on all pages and only heading/artwork inside the pager. Large accessibility text retains a scrolling fallback.
- Added a runtime radial opacity mask to soften illustration backgrounds without editing supplied artwork. Original dark background can still be visible near artwork.
- Replaced Google PNG usage on onboarding/login/signup with official vector downloaded from https://fonts.gstatic.com/s/i/productlogos/googleg/v6/24px.svg, located after consulting https://developers.google.com/identity/branding-guidelines.
- Native iOS LaunchScreen.storyboard explicitly used white; changed it to black. This addresses launch color only, not the unresolved Xcode debugger startup delay.
- Four widget tests passed, including 375×667 footer visibility/position across swipes, all-page render checks, sign-in loading/error behavior, and 200% text scale. Inspected compact render. User will rebuild/test using Xcode; no automatic device launch performed.

## Xcode deployment-target correction — 29 October 2026

- User's Xcode build failed because generated FlutterGeneratedPluginSwiftPackage declared iOS 13 while firebase-auth/firebase-core require iOS 15. Runner project configurations were already iOS 15.
- Ran `flutter build ios --config-only --no-codesign --debug` successfully to synchronize generated package deployment target using Flutter's supported preparation path. No device build/install/launch was performed. Xcode rebuild remains user verification.
- After Flutter commands regenerate plugin metadata, repeat configuration-only preparation before a direct Xcode build if this mismatch recurs; do not manually patch the SDK or generated Package.swift.

## New vector illustration concepts — 29 October 2026

- Created four editable SVG concepts in `Artifacts/onboarding-vectors/`: welcome court/balls, nearby player markers, court/calendar booking, and connected-player matchmaking. Shared lime/gray palette and transparent SVG backgrounds.
- Rendered and visually inspected all four with macOS Quick Look. Quick Look PNG previews have a white background; SVG source backgrounds are transparent. `preview.html` displays the SVGs against black.
- Awaiting visual approval before replacing app artwork. Flutter SVG rendering/filter compatibility has not yet been tested; these are review assets, not integrated production assets.

## Final PNG artwork and fluid indicators — 29 October 2026

- Inspected all four `Artifacts/onboarding-final/` images: 1254×1254 RGBA with real alpha transparency. Copied them unchanged into mobile assets (booking mapped to arenas.png). Original source files preserved.
- Removed the old radial fade mask and added 8px image padding with contain fitting. No cropping or image regeneration. Minor pale cutout fringes remain in supplied source art; inspected all four 402×874 renders and compact 375×667 render against black.
- Indicators now interpolate width and color directly from PageController position during dragging and settling, including reversals. Reduced-motion mode uses discrete indicators. Footer remains stationary.
- Five widget tests passed, including partial-drag/reversal, compact footer visibility, all four render/action checks, sign-in busy/error behavior, and enlarged text. Flutter analysis passed. Physical-device animation/performance remains for user's Xcode test.
- iOS configuration-only preparation completed successfully for direct Xcode rebuild; generated Swift package minimum verified as iOS 15. No automatic device launch performed.

## Login and sign-up polish — 29 October 2026

- Reviewed auth-login/auth-create references and current forms. Added compact signup sizing (smaller brand/title and gaps) so normal-size text fits 375×667, while keyboard/errors/large text retain scrolling. Kept reference colors, rounded fields, white primary action with lime arrow, and official Google SVG.
- Added input autofill hints, name capitalization, stricter email whitespace checks, Next/Done keyboard actions, password visibility tooltips, 48px account-switch target, and error validation updates after the first submission. Mode changes clear passwords/validation state.
- Pending auth disables fields and both actions; only the action in progress shows a spinner. Added an explicit duplicate-submission guard. Google cancellation is quiet; errors allow retry. Backend session integration remains a separate pending milestone.
- Added injectable AuthService for isolated tests. Ten mobile tests passed before final alignment adjustments; five focused auth tests cover compact layout, validation/password toggle, busy/error recovery, 200% text size, and reference/compact renders. Inspected both forms at 402×874 and 375×667. Test-render typography uses installed SF; physical-device fidelity is not yet verified.
- Next: user rebuilds in Xcode and checks signup layout, keyboard navigation, autofill, and sign-in on iPhone. Device testing remains user-controlled.
- Final verification: all five focused auth tests passed after button-centering/background adjustments; mobile analysis passed. Configuration-only iOS preparation succeeded and generated package minimum remains iOS 15. No app launch or installation performed.

## Xcode startup and lag investigation — 29 October 2026

- Inspected the supplied 5,629-line runtime console capture and latest local Runner build activity log (`70EED185-9059-435F-A798-381F2EBB3F87`). Latest build succeeded; warnings included unknown Swift debug environment variables and skipped App Intents metadata extraction.
- Runtime capture confirms Debug/JIT with LLDB. It contains 5,235 repeated keyboard property warnings and 19 Auto Layout conflicts naming iOS keyboard prediction views (`TUIPredictionViewCell`/`TUICandidateGradientContentLabel`), plus system gesture timeouts. No Dart exception or Flutter layout failure found. A single Firebase pre-configuration warning does not establish an initialization failure. The capture lacks startup timings and frame profiling, so the cause of the long blank launch and interaction lag is not yet proven.
- Startup now waits until the first Flutter frame completes before calling Firebase/Google initialization. Added non-release timing messages for the first frame (measured from startup widget creation, not native process launch) and each service. This does not resolve or measure a delay before Dart/Flutter starts.
- Auth gate now retains its authentication stream across rebuilds instead of creating a new stream in `build`. Kept keyboard/autofill behavior and existing designs intact; did not suppress native console warnings or alter the Xcode run scheme.
- Verification: Flutter analysis passed and all 12 mobile widget tests passed, including two new startup tests for loading-before-initialization, single initialization across rebuilds, and service failure handling. Widget tests do not establish physical-device rendering performance. No app install or launch performed.
- Next: guide user through an Xcode Profile-mode run on the physical iPhone, compare launch/typing/swipe behavior, and collect `[Startup]` timings. Flutter recommends physical-device profile mode for representative performance measurements: https://docs.flutter.dev/perf/ui-performance.
- After tests, configuration-only iOS preparation succeeded; generated Swift package minimum verified as iOS 15. No native device build or device performance verification was performed.

## Release console follow-up — 29 October 2026

- User reports the Release app launched. Verified Runner Run scheme is Release with no LLDB debugger attached.
- Reviewed all unique messages in the new 19,634-line console capture: 19,500 lines are repetitions of five iOS keyboard-rendering property warnings; another 95 concern keyboard variant selection. Remaining messages concern focus caching, system process inspection, scene/keyboard snapshots, handler registration, and one Firebase pre-configuration notice. No Dart exception, Flutter layout exception, authentication failure, or crash is present in this capture. This does not prove the app is issue-free or establish whether lag remains.
- Reviewed auth input settings: autocorrect and suggestions are already disabled. Current Firebase setup initializes using Dart FirebaseOptions, consistent with Firebase's Flutter setup documentation. No evidence here justifies adding duplicate native configuration, private entitlements, suppressing system logging, or removing autofill.
- No application code changed during this follow-up; no additional tests run. Need physical-device reproduction details to distinguish ongoing keyboard performance problems from console-only diagnostics. Next: ask user whether Release typing/swiping still lags, then isolate the specific triggering action if it does.

## Auth input typography — 29 October 2026

- User confirmed Release typing and swiping are now smooth on iPhone.
- Login/signup inputs and hints now explicitly share 16px regular text, neutral letter spacing, and 1.5 line height. Platform font selection remains in place (SF on iOS); added a slimmer 1.5px lime cursor. This avoids inheriting Material field tracking and hint weight. No font dependency or global theme change.
- Verification: Flutter analysis passed and all five focused auth widget tests passed. Refreshed existing reference/compact renders and added populated login/signup renders; visually inspected both populated forms at 402×874 using locally installed SF typography. These test renders do not establish physical-device fidelity.
- Next: rebuild in Xcode Release and review typed name/email, password dots, and cursor on iPhone. No device installation or launch performed.
- iOS Release configuration-only preparation completed successfully for the next direct Xcode build.

## Mobile backend session integration — 29 October 2026

- Added `AccountSessionService` and a server-confirmed account model under `apps/mobile/lib/features/auth/`. Email, Google, and restored Firebase sessions now pass through backend setup before reaching the signed-in placeholder. Response validation checks identity/profile IDs, account status, and role consistency; backend authorization remains authoritative.
- Added an identity-keyed `AccountSessionGate` with loading, explicit retry, suspended/rejected-token/configuration messages, and sign-out recovery. Parent rebuilds do not repeat setup; late results from a previous identity cannot unlock the current identity. A 401 refreshes the Firebase token once and repeats the idempotent setup request once.
- Shared the same AuthService across the auth gate, onboarding, and forms. Signup auth events wait for display-name saving before backend account creation. Firebase sign-out occurs before best-effort Google cleanup, so a Google cleanup failure does not keep the application session open.
- API client now rejects missing tokens locally and bounds token acquisition and each HTTP exchange to 20 seconds. Per-attempt HTTP clients close after setup. No tokens, account payloads, or credentials are logged.
- Verification: all 21 mobile tests and 10 mocked backend tests passed. Nine new mobile checks cover session requests, token refresh/repeated rejection, invalid or cross-account responses, configuration/token/timeout failures, signup sequencing, restored-session loading, retry/sign-out recovery, suspension, and stale completion. Flutter analysis passed after removing a redundant null check. Running two Flutter tools concurrently initially caused a generated-plugin symlink collision; sequential analysis completed successfully. No native build, device launch, deployment, or live Firestore writes performed.
- Updated `docs/SETUP.md` and current next-step notes. A reachable `API_BASE_URL` is still needed before the next live integration checkpoint; a build without this setting will show a configuration message after Firebase sign-in. Real token verification, database persistence, and phone networking remain unverified.
- Next implementation milestone: profile setup and sport selection, with backend persistence. Keep routine verification local; schedule device/API integration at a meaningful checkpoint as requested.

## Profile setup and unique usernames — 29 October 2026

- Added post-authentication routing: accounts without server-confirmed profile completion enter two-step username/sports setup; completed accounts skip it on later sessions.
- Added authenticated username availability and own-profile save endpoints. Usernames are lowercase, 3–20 ASCII letters/numbers/underscores/dots, starting with a letter/number. Firestore username documents provide transactional uniqueness: reservation, profile update, and old-name release occur together; final save rechecks ownership and suspension. Availability alone does not reserve a name.
- Added debounced availability checks with stale-result protection, disabled actions, conflict recovery preserving sports, saving/error states, back navigation and sign-out. Six sports use consistent glyphs with a custom badminton shuttlecock, selected borders/checkmarks, and an enlarged-text single-column fallback.
- Adapted the supplied references with initials avatar, explanatory copy, explicit step labels and sign-out. Photo upload is not implemented. Icons are Material plus a custom shuttlecock, not exact SF Symbols. Footer placement differs from references. Profile availability/bio/radius/location editing remain future steps.
- Verification: 12 mocked backend tests passed, covering username validation, conflicts, own-claim retry and transaction suspension checks. Existing 21 mobile tests passed during the initial full run; the new profile test initially needed a frame after sport selection, then passed covering availability, conflict recovery, preserved selection and successful save. Inspected local 402×874 profile renders; device fidelity and concurrent real Firestore transactions remain unverified. No device build or live writes.
- Next: location permission/manual-area setup and discovery foundation, after agreeing the next milestone. Live API configuration remains required at the integration checkpoint.

## Location permission and manual-area workflow — 29 October 2026

- Added location setup after completed username/sports setup. Restored profiles with saved coordinate maps skip it. Users confirm a GPS/manual selection before saving; denied permission, disabled services, permanent denial/settings, timeouts, empty results, unavailable search configuration, and save errors have recovery paths. Search is debounced with stale-response protection; failed saves preserve selection.
- Added separate LocationService and LocationSetup components. Geoapify autocomplete supplies area choices; reverse geocoding is best effort after GPS. Without a configured Geoapify key, manual lookup reports configuration unavailability while GPS remains usable. No live Geoapify requests were sent in verification.
- Added geolocator 14.1.2 (official documentation/license inspected; dependency resolution succeeded), Android coarse/fine/internet permissions, and iOS when-in-use text. Only a single foreground position is requested on tap. Native permission dialogs, SDK integration and SPM distribution macro setup remain device/build checkpoint work.
- Added protected PUT /api/v1/me/profile/location with strict field, finite coordinate/range, source and label validation. Transaction reads current user/profile, enforces profile completion and suspension, and updates only location fields for the verified UID. Stored Firestore GeoPoints now serialize correctly in session, account and profile responses.
- Verification: 15 mocked backend tests passed; three new mobile location tests passed for parsing, missing configuration, denied-permission manual fallback, failed save preserving selection and successful retry. Flutter analysis passed. Inspected the local 402×874 location screen render; it is a new screen extending the black/lime design, not an exact supplied reference. Real GPS, live geocoding/database persistence, native builds, and physical-device visuals remain unverified.
- Next: build the Explore map foundation using the saved location. A reachable API address and locally configured Geoapify key remain prerequisites for live integration.
- Final mobile regression: all 25 tests passed after location integration. No device build performed.

## Explore map foundation — 29 October 2026

- Replaced the signed-in placeholder with Explore after profile/location setup. AccountSession now retains validated coordinates/label/source; location setup returns the confirmed Area, so both new and restored sessions center correctly. Area changes preserve the previous selection until saving succeeds and provide a Back to Explore control.
- Added flutter_map 8.3.2, latlong2 0.10.1 and url_launcher 6.3.3; dependency resolution succeeded. Inspected flutter_map's BSD license and current official Geoapify tile documentation.
- Added Geoapify dark-matter tiles, saved-area marker, pan/zoom, recenter, area-change action, account sign-out and clickable Geoapify/OpenMapTiles/OpenStreetMap attribution. Tile progress, timeout/error and explicit retry states are included; callbacks from previous attempts are ignored. Missing key shows a configuration state without network tile requests.
- Reference comparison: dark-map/lime direction follows explore.png. Current foundation uses a separate header/area row and visible attribution footer. Game markers/cards, sport filters, AI/create actions and multi-tab navigation remain future working features. No fake games or discovery results are displayed. Exact reference matching and native performance are not claimed.
- Verification: all 28 mobile tests passed; Flutter analysis passed. Three new checks cover coordinate validation, missing configuration, mock-tile rendering, saved marker, recentering and account actions. Inspected local 402×874 layout render with solid mock tiles; it does not verify real street imagery. No live tile requests, API/database writes, native build, device installation or launch performed.
- Next: implement backend game creation and nearby-game discovery, then populate Explore with actual games and working sport filters.
- Extended map verification to tile-error retry and stale callbacks. A test exposed a missing frame request for asynchronous errors; added an explicit visual update and guards against redundant frames. Focused retry checks passed after the fix.

## Explore reference correction and live tiles — 29 October 2026

- User rejected the separated header/footer layout and missing navbar. Rebuilt Explore as a full-screen live-map Stack with overlaid title/actions, sport chips, white recenter/reset controls, and the floating black four-icon navbar. Removed the large placeholder banner and attribution-link footer; credits remain in a compact map strip opening attribution details.
- Activity/Arenas/Create controls currently open explicit pending-feature panels; Profile provides change-area/sign-out. AI remains a labelled pending feature. Sport chips track selected state; actual game filtering awaits game discovery. No fabricated game cards were added.
- Found existing Geoapify key in ignored backend environment; verified a live PNG tile returned HTTP 200. Copied the key into ignored apps/mobile/.env.json without printing it; updated VS Code launch configuration to read that file. Fetched real Lahore map tiles for a separate real-imagery UI render. Production rendering continues to use live Geoapify URLs.
- Real-tile render is a local Flutter layout capture using freshly fetched Geoapify tiles, not a physical-device screenshot or a claim of end-to-end phone verification. Backend API address is still required for the protected sign-in workflow; no native device build or launch performed.
- Final verification: all 28 mobile tests and Flutter analysis passed. Separately rendered the final street-level layout using fetched live Geoapify imagery and visually inspected navbar, controls, header, chips and compact attribution. Test previews remain local renders, not device captures. Sport chips currently change selection only; no game query exists yet.

## Same-Wi-Fi iPhone API preparation — 29 October 2026

- User explicitly requested preparing the backend on the Mac for iPhone testing. Started Flask on 0.0.0.0:5001 without debugger/reloader (tool session 81071). Verified /health returns HTTP 200 via localhost and Aafaqs-MacBook-Pro.local. This is a development server and requires the Mac/session to stay running.
- Added API_BASE_URL=http://Aafaqs-MacBook-Pro.local:5001 to ignored mobile .env.json alongside the verified Geoapify key. Added iOS local-network purpose text and NSAllowsLocalNetworking, following Apple's documentation; global arbitrary networking remains disabled.
- First iOS configuration-only preparation completed after resolving Swift packages. Preparing the final combined API/map configuration next; no native app compilation, signing, installation, or physical-phone network test performed. Real sign-in/Firestore writes still require user device verification.
- Final combined iOS configuration-only preparation succeeded. Verified generated Xcode configuration contains the intended local API URL and a nonempty Geoapify key without printing that key; generated Swift package target remains iOS 15. Info.plist validation passed. Awaiting iPhone Safari health check before installation guidance.
- User confirmed iPhone Safari reaches the Mac API /health endpoint and displays status ok over the same Wi-Fi. Physical-phone network reachability is now verified by the user; app installation, native permissions, authenticated session/Firestore persistence and live map behavior inside the app remain pending.

## Branded launcher icon — 29 October 2026

- Created square black/lime app-icon artwork from the supplied playerszwz-logo.svg without changing its paths or brand color. Editable master and PNG preview are under Artifacts/app-icon/. Kept corners square for the operating system to mask.
- Replaced all 15 unique PNG files referenced by the existing iOS AppIcon catalog, including the 1024px marketing icon. Exporter verified expected dimensions and no alpha for every output; checked Xcode still targets AppIcon.
- Replaced Android launcher PNGs in all five existing densities. Added Android 8+ adaptive icon with black background and vector foreground sized within the circular safe region; roundIcon points to the same adaptive resource. Existing manifest icon reference remains valid.
- Verification: visually inspected 1024px master and 48px Android export, validated Android XML, and checked native icon references. No Flutter business logic changed, native build performed, or device installed. Appearance on the iPhone Home Screen and Android launcher masks remains unverified until installation.
- Next: install the updated app through Xcode and check the branded Home Screen icon alongside the sign-in-to-Explore flow.

## Platform navigation and setup redesign — 29 October 2026

- User reported the working app's frontend felt generic and requested platform-appropriate navigation and a coherent Profile → Location → Explore flow. Re-read AGENTS.md, PLAN.md and the supplied profile/Explore references; consulted current Apple tab-bar/material guidance, Material navigation guidance, Flutter platform-view documentation, and design-engineering/Swift skills.
- Added SetupFrame for consistent title/subtitle spacing, three-step progress, account overflow menu, independent scrolling, and a persistent primary action above the keyboard. Profile retains live username availability, stale-response guards, atomic server conflict recovery and selected sports. Restyled the sports grid with cohesive glyphs, selected checks, subtle selection transitions and haptic feedback; enlarged text switches to one column.
- Location uses the same setup frame, a clear foreground-location action, manual search, selected-area confirmation and retry/settings states. Provider credits appear with search results. Manual search clears stale permission-settings guidance. Protected backend behavior is unchanged.
- Added PlatformNavigation: actual UIKit UITabBar with SF Symbols and system appearance on iOS, registered through the Flutter implicit-engine lifecycle; Android uses Flutter Material 3 NavigationBar with labelled destinations and a selected indicator. Native selection is synchronized through a bounded method channel; callbacks are removed on disposal. No glass shader imitation or new dependency. UIKit owns its version-specific appearance; iOS 27-specific behavior is not claimed.
- Explore remains a live Geoapify map with preserved viewport across tab changes, saved-area label, search, recenter, connection retry and required credits. Removed the nonfunctional AI/create/filter affordances. Profile is a real destination showing account name, saved area, area change and sign-out. Activity/Arenas now have stable destinations with explicit future-availability states; game participation and arena booking are still unimplemented, not fabricated empty datasets.
- Reference departures follow the user's request for platform adaptation: labelled native-style navigation replaces the universal black icon pill; setup actions are fixed and progress covers location as well as profile; unsupported map actions are omitted. Black/lime palette, sports tile proportions and white pill primary-action direction are retained.
- Verification so far: Swift type-check passed for the native component and AppDelegate against the installed iOS 26.2 SDK and Flutter framework; Xcode project syntax validated. Focused Flutter checks cover username conflict recovery, denied GPS/manual search/save retry, tab destinations/back, bidirectional native navigation messages and keyboard-safe actions. Visually inspected software-rendered setup screens and an Android Explore preview using previously fetched real Geoapify tiles. These are local previews, not iPhone screenshots. Final mobile regression/static results follow below.
- User reports the earlier installed app works; that report predates this redesign and the icon upgrade. No app build, installation, account change, backend deployment or commit performed in this milestone. UIKit glass compositing, safe-area appearance, native VoiceOver and motion performance still require physical-device verification.
- Next: review the redesigned flow and native tab bar on the user's iPhone before expanding the game-discovery milestone.
- Final verification: all 31 mobile tests passed. The profile sports grid and selected location screen were exercised at 200% text on a 375×667 viewport; the shared primary action was also checked above a simulated 280px keyboard. Native navigation creation, valid/invalid selection callbacks and Dart-to-native selection updates passed mocked bridge checks. Flutter analysis finished with no issues. Native Swift type-check and Xcode project syntax check passed; no iOS/Android app build or physical-device verification was performed.

## Setup placement, motion and profile photos — 29 October 2026

- Followed the user's specific correction: removed top-left progress and setup sign-out menus. The shared SetupProgress now sits centered immediately above the primary action, matching onboarding's white 31px active pill / 7px inactive dots. Removed sports selection counts and footer username copy; username guidance is now immediately beneath the field. Sign-out remains in the Profile tab (and authentication recovery where signing out is necessary).
- Cleaned profile creation against create-profile-01.png: removed the extra subtitle/name block, added a tappable circular photo with an add badge, and retained the username field and inline status. The three progress steps cover identity, sports and area.
- Added shared motion primitives: setup stages slide/fade over 280ms with the existing iOS-like curve, reverse appropriately on back, exclude outgoing controls from interaction/accessibility, and reset each new form's scroll position. Reduced motion uses a 120ms fade without travel. Main buttons, sports tiles and photo controls get 120ms press feedback. Dots animate over 250ms using onboarding's dimensions and easing.
- Replaced the map dot with a distinct saved-area pin and static halo (not an accuracy radius). Recenter interpolates projected map coordinates and zoom over 280ms, retargets from the current camera, uses the short date-line path, stops on drag/tab change, and moves directly with reduced motion. It still returns to the saved area; it does not silently request or imply a new GPS fix.
- Removed the large Explore attribution panel and used a narrow credit line plus map-info control. Did not delete required credits: Geoapify's current documentation requires Geoapify branding on free plans, OSM credit, and OpenMapTiles credit for this tile style. A paid white-label entitlement has not been established. The user has been told this remaining difference explicitly.
- Added image_picker 1.2.4 (Flutter-maintained, BSD licence; dependencies resolved) and iOS photo-library purpose text. Profile creation and the Profile tab share a user-scoped photo controller. Gallery choice opens a circular preview before explicit save; cancel makes no write, failed replacement retains the confirmed image, and users can replace/remove the photo. Android lost selection is recovered for explicit review, never auto-uploaded.
- Added protected GET/PUT/DELETE /api/v1/me/profile/photo. The backend verifies Firebase identity, active status and profile existence, derives ownership from the token, bounds request/image dimensions, decodes JPEG/PNG/WebP, strips metadata, and creates a square 512px JPEG thumbnail capped at 128 KiB. Pillow 13.0 installed locally and declared in requirements. The thumbnail is stored in profiles/{uid}/media/avatar, separately from session/profile data, with no new account/bucket/billing configuration. This is deliberately bounded avatar storage; original/full-size media is not stored and future general media should use object storage.
- Verification: all 40 Flutter tests and 24 mocked backend tests passed; Flutter analysis has no issues; Info.plist validated. Added checks for centered progress/no setup sign-out, large text/keyboard behavior, outgoing-page isolation/reduced motion, progressive and interrupted recentering/date-line travel, photo preview/cancel/retry/duplicate blocking/restoration, Android recovery, image validation/metadata stripping/size bounds, token ownership and suspension. Fixed a lazy animation-controller disposal bug and a picker spinner that incorrectly remained active behind the preview sheet, both exposed by tests.
- Refreshed the existing Mac development API (old PID 21053; new tool session 29643) with the new routes. Health returns 200/status ok and unauthenticated photo access returns 401. No live personal-photo upload or Firestore write was performed during verification. Existing API URL remains http://Aafaqs-MacBook-Pro.local:5001.
- No app build or installation performed. Actual iPhone/Android gallery permissions, HEIC handling, photo persistence through the real API/database, UIKit appearance, and animation performance still need device verification. Updated setup goldens were inspected against references; Explore real-imagery preview uses already-fetched Geoapify tiles rather than a device screenshot.
- Next: test photo selection/saving and the complete setup-to-Explore transitions on the iPhone.
- Final interaction follow-up: press scaling now releases as soon as a tap becomes a drag; the new focused regression passed alongside setup/reduced-motion and Explore checks. The full 40-test suite passed before this addition, and the additional test plus affected suites passed afterward (41 mobile cases now). Static analysis remains clean. Corrected the preview capture to wait for recenter completion before tile decoding; visually inspected the final preview with real street imagery, new marker and compact attribution.

## Direct Xcode package-target repair — 29 October 2026

- User's screenshot showed Firebase auth/core require iOS 15 while FlutterGeneratedPluginSwiftPackage had reverted to iOS 13. Runner configurations were already iOS 15. Inspected the installed Flutter SDK: dependency/plugin generation writes the default platform; iOS build preparation subsequently synchronizes it to Runner's deployment target. The final Flutter checks from the preceding milestone regenerated the lower default; the missing final preparation was acknowledged.
- Ran `flutter build ios --config-only --no-codesign --debug --dart-define-from-file=.env.json` successfully. Verified generated package and Runner both target iOS 15, image_picker_ios remains included, and API/map defines match the ignored local configuration without exposing their values.
- Updated docs/SETUP.md to run configuration preparation after the last dependency/test/analysis command before direct Xcode handoff, and to preserve the local defines file. No manual generated-file/SDK patch, app compilation, signing, installation, or cache cleanup performed. The actual Xcode build remains user verification.
- Next: retry the build in Xcode with the synchronized package target.

## Branded launch and loading presentation — 29 October 2026

- Added a black, logo-only Flutter launch screen with a 900ms minimum presentation while services initialize, followed by a reduced-motion-aware fade. Returning authenticated users see a signed-in identity card with a green shield icon and a bottom loading indicator while the backend session loads. No sign-out control appears during account loading; error recovery retains sign-out where reauthentication may be necessary.
- Welcome-to-auth forms and account-gate content now use the shared slide/fade transition, complementing existing setup transitions. Added semantic success/error colors; username availability uses green and setup/photo failures use red. Lime remains for brand actions and sport selections.
- Replaced the decorative lime pin with a Google-Maps-inspired blue dot/white border. It continues to identify the saved area, not live GPS tracking or measured accuracy. Recenter uses a smaller 44px white control with a gray crosshair and retains interruptible camera animation.
- iOS search uses a Flutter-rendered translucent blur, border and circular touch target. This is glass-style styling, not UIKit's native Liquid Glass/refraction. Physical-device appearance and performance remain unverified.
- Full mobile regression and analysis passed before the final focused identity-card check. Updated startup assertions for the intentional logo dwell and account retry assertions for outgoing transition duration. No backend changes, native app compilation or device installation. Final configuration preparation follows the tests to keep generated Swift packages at iOS 15.
- Next: inspect fresh-launch and returning-user transitions on the iPhone.
- Final checks: the focused startup/profile tests passed (4 cases, including the new signed-in card layout check), and analysis reported no issues. The full 41-case suite passed before that additional test. Configuration-only iOS preparation completed successfully; generated package and Runner target iOS 15, and API/map defines match the local configuration without exposing values.
- Native startup follow-up: reused the existing branded icon PNG in the iOS launch image catalog with bounded aspect-fit layout, replaced Android's default launch backgrounds with black and the existing brand vector, and supplied Android 12+ black splash styling. All edited native XML parsed successfully. Native compilation and physical-device appearance remain unverified.

## Sprint 1 remaining-work review — 29 October 2026

- User confirmed the latest launch experience works on iPhone, profile photos persist after reopening, and the selected location persists. These are user-reported device checks; they do not establish Android acceptance or every permission/error scenario.
- Compared PLAN.md Sprint 1 tasks with current source. Auth/session middleware, central mobile API client, username/sports setup, profile photos, GPS/manual area selection and live map foundation are implemented. Explore search already invokes the change-area flow; suggesting it as a new missing feature was incorrect.
- Task 1.9 remains incomplete: no full profile-edit destination for existing users, and no availability, radius or bio input/save support. Existing profile save accepts username/sports only; Profile tab currently offers photo, area and sign-out.
- Task 1.12 remains incomplete: infra/firebase contains guidance only, with no versioned Firestore rules/indexes. Live console rules were not inspected in this review.
- Tasks 1.1/1.13 remain incomplete locally: no commits or configured remote in this checkout, no .github CI workflows, and team repository access/branch setup not verified. Git operations remain explicitly deferred by the user.
- Task 1.14 is partial: ignore rules and local environment/setup guidance exist, but no configured secret scan or per-app READMEs were found. Task 1.2 audit exists but is stale and not a complete current screen/endpoint classification.
- Task 1.15 remains incomplete: API is served by the Mac over local Wi-Fi; no hosted API deployment/configuration is recorded. External account changes and deployment require authorization.
- Sprint acceptance still needs Android checks and explicit device verification of invalid-login errors and denied-location/manual fallback. Saved-area recentering is implemented, not continuous GPS tracking.
- PLAN.md inconsistently lists FCM-token registration under Sprint 1 in Section 8.2 while assigning device-token registration/FCM to Sprint 4 in Task 4.3; flag for scope clarification rather than silently moving it. No PLAN.md edits made.
- Review only; no app build or automated tests rerun. Next: complete Sprint 1 task 1.9, profile editing with availability, radius and bio, before starting Sprint 2 games.

## Vercel deployment preparation — 29 October 2026

- User selected Vercel and requested one step at a time. Current screenshot is the New Project screen; existing connected repositories shown there do not include PlayersZWZ. Git operations remain deferred, so plan CLI deployment from services/api rather than importing unrelated projects or uploading the raw folder.
- Added Flask index.py entry point, Python 3.14 selection (matches local test runtime), Vercel Flask configuration and an allowlist upload exclusion file. Local secrets, .env, virtual environment and tests are excluded from CLI deployment; browser drag/drop exclusion behavior has not been verified.
- Added server-side FIREBASE_SERVICE_ACCOUNT_JSON support with project matching and generic credential errors, preserving local file credential support. Vercel disables debug mode; local development retains its existing configuration. Updated setup documentation and environment example.
- All 28 backend unittest cases passed, including 4 new checks covering JSON credentials, malformed/mismatched configuration, local credential fallback and entry-point health/auth rejection. Firebase/Firestore operations are mocked; no Vercel build, upload, account change, credential write, Git operation or deployment performed. Mobile build/configuration unchanged.
- Next: authenticate Vercel CLI with the existing Hobby workspace, then create/review the project and sensitive environment configuration before deployment.

## First Vercel production deployment — 29 October 2026

- User completed CLI login, linked playerszwz-api in the Hobby workspace, and reports saving production/preview configuration and Firebase JSON secret. User deployed successfully; CLI reported Ready and alias https://playerszwz-api.vercel.app. Secret contents were not shared or inspected.
- Independent public HTTP checks after deployment: /health and unauthenticated /api/v1/me both returned HTTP 500 FUNCTION_INVOCATION_FAILED. Build readiness does not establish runtime startup success. Need Vercel runtime traceback before diagnosing root cause; credentials and dependencies are not yet confirmed on the deployed runtime.
- Mobile still uses its existing local API configuration. Do not switch to the cloud endpoint until startup and protected endpoint checks pass. Next: inspect Vercel runtime logs for failed invocations and repair the root cause.

## Vercel missing-package repair — 29 October 2026

- User runtime traceback: index.py import fails with ModuleNotFoundError for app. Inspected installed Vercel 65.7.0 ignore matcher: original allowlist includes app sources, so upload exclusion was not established as root cause. Runtime/bundle omission remains the observed issue.
- Added explicit functions.index.py.includeFiles=app/** and explicit recursive app allowlist. Verified with the installed CLI ignore implementation that all 15 Python package sources are included and .env/.env.local, service-account file, virtual environment and tests are excluded.
- Clean temporary staging of only index.py and app imports correctly; /health returns 200 and unauthenticated /api/v1/me returns 401. These local checks do not reproduce Vercel's remote build. Need fresh upload/build to confirm the explicit bundle inclusion resolves the deployed error. No credential changes, Git actions or new deployment performed by agent.
- Next: user redeploys local repaired source with --prod --force, then recheck public runtime endpoints. Redeploying the previous remote source alone would omit this local fix.
- Second deployment still failed with the same import. Read runtime logs and remote deployment file listing via authenticated CLI: remote src contained only the four root files, proving upload traversal omitted app entirely. Reproduced exactly using installed CLI buildFileTree (not just ignore checks on leaf paths). CLI checks the directory path `app` without trailing slash, so !app/ does not reopen traversal under /*. Corrected to !app, retained !app/**; excluded cache directory nodes explicitly too. Actual CLI upload tree now includes all 15 app package Python files plus 4 root files and excludes secrets/env/venv/tests/caches. This replaces the earlier incomplete leaf-only verification. Need redeployment of this corrected source and public HTTP checks.

## Vercel startup verified — 29 October 2026

- User deployed corrected upload rules; production alias remains https://playerszwz-api.vercel.app (deployment 3mZXhf66twg2kQrjoaqn5PYPYx6B).
- Independent public HTTPS checks passed: GET /health returned 200 with status ok/service playerszwz-api; GET /api/v1/me without a bearer token returned 401 UNAUTHORIZED. App package startup issue is resolved and public requests reach Flask without Vercel sign-in.
- These checks do not validate Firebase credentials or real authenticated Firestore operations. Mobile still targets the local API. Next: update the mobile API URL, prepare iOS configuration, rebuild/install at the agreed device checkpoint, and verify existing-account/photo/location operations on mobile data with Mac backend off.

## Mobile switched to Vercel configuration — 29 October 2026

- User approved connecting the mobile app after public Vercel health 200/auth rejection 401 verification. Changed only API_BASE_URL in ignored apps/mobile/.env.json to https://playerszwz-api.vercel.app, preserving all other values including the map key. Removed the Android emulator local-API override from .vscode/launch.json so IDE launch uses the same cloud config.
- Successfully ran configuration-only iOS Release preparation, without native compilation/signing/installation. Verified Generated.xcconfig defines match the cloud URL and existing map key without printing the key, and generated Swift package still targets iOS 15. Existing Runner Run action already uses Release. Updated setup documentation to distinguish old LAN development from active cloud configuration.
- No application logic changed; validated configuration directly rather than rerunning unrelated Flutter tests. Authenticated Vercel Firebase operations remain unverified. Previously installed iPhone app retains its compiled local URL until rebuilt/reinstalled. Next: user installs from Runner.xcworkspace on iPhone, then checks the restored session over cellular with Wi-Fi off/Mac API stopped, followed by photo/location persistence.

## Minimal API service pages — 29 October 2026

- Implemented shared responsive black/lime home, browser health and browser 404 pages with original vector logo/favicon, system font fallback, focus/skip navigation, reduced-motion support and semantic green/red state cues. Kept content minimal as requested rather than expanding into a marketing website. No external fonts, scripts or services required.
- Root now renders HTML. /health renders a status page only when Accept prefers HTML; default/JSON callers retain the original JSON, and ?format=json explicitly selects JSON. Health responses have no-store and Vary: Accept. Health copy accurately describes API liveness, not Firebase/map availability. Unknown /api/ routes always return JSON 404; browser non-API unknown paths render HTML with actual 404 status.
- Verified seven route/content-negotiation scenarios, all 28 existing backend tests, and the actual Vercel CLI file tree includes the shared HTML template. Initial full-suite invocation from repository root had import errors; rerun from services/api passed. Visually inspected home, health and 404 in the local browser at its narrow viewport; full desktop/device testing not claimed. Local preview on 127.0.0.1:5057 (session 94156) is only for this review, not a dependency of the deployed app.
- No production deployment or mobile rebuild performed. Next: user deploys the updated API source, then verifies the public home and health pages. Mobile-data authenticated testing still outstanding.

## Centered service-card refinement — 29 October 2026

- Adapted the user's card reference into the shared home, health and browser 404 template: centered dark card, subtle border, original PlayersZWZ logo, status badge, inset information panel, lime actions and outside footer. Added responsive mobile spacing and retained reduced-motion support; green health and red error cues remain distinct from brand lime.
- Verified all three rendered pages visually in the local desktop browser and six Flask route/content-negotiation checks passed. API JSON responses and real 404 status remain intact. Mobile breakpoint styling is implemented but not visually rechecked in this refinement. Preview runs locally on port 5057 (session 3196).
- No deployment, mobile build or account changes performed. Next: deploy the updated API to Vercel and verify public pages.

## Production API URL documentation correction — 29 October 2026

- Corrected the active mobile API URL in `docs/SETUP.md` to `https://playerszwz.vercel.app`, matching the current ignored `apps/mobile/.env.json`. Earlier `playerszwz-api.vercel.app` entries remain as historical deployment records, not current configuration guidance.
- No application code, runtime configuration, build, deployment, or external account settings changed. Next: reinstall the Android app with the current API URL and verify Google account setup.

## Mobile runtime configuration — 29 October 2026

- Added public `GET /api/v1/mobile-config`, which returns only the Geoapify map key from the API environment and returns a generic 503 when it is absent. The Flutter app now defaults its API host to `https://playerszwz.vercel.app` and loads the map key at startup; production installs no longer require Dart defines.
- Added backend endpoint coverage and a Flutter runtime-config test. The tests were not run in this step at the user's request. Vercel still needs its `GEOAPIFY_API_KEY` environment variable set and the API source redeployed before installed apps can receive the map key.

## GitHub release staging — 29 October 2026

- Added the tracked root-level `Releases/Android/README.md` staging guide and ignored `Releases/Android/*.apk`. Android test APKs should be attached to versioned GitHub Releases rather than committed into source history; no iOS artifacts belong in this directory.

## Service copy and footer polish — 29 October 2026

- User selected service-online copy and clarified sports matchmaking positioning. Home now reads “PlayersZWZ is online.” with “The PlayersZWZ service is online. Open the app to connect with players near you.” Removed game wording from the home detail panel and footer. Shared footer now shows © 2026 PlayersZWZ. All rights reserved. and Sports matchmaking platform.
- Heading clipping fix from the interrupted previous step is retained: increased line height, bottom breathing room and solid text instead of background-clipped gradient. Local rendering checks passed for home/health/404, shared footer and unchanged health JSON. No new visual inspection or deployment performed.
- No Git remote is configured, so a repository URL cannot be verified; GitHub footer link awaits the user's URL. Next: add the supplied repository link.

- Footer follow-up: removed right-side Sports matchmaking platform text at user request. Copyright remains; GitHub link is pending the repository URL (no Git remote configured). No deployment performed.

- Found repository reference in docs/audit.md and verified public pvrplxd/PlayersZWZ through connected GitHub. Added GitHub footer link with safe new-tab attributes on all service pages. No deployment performed.
