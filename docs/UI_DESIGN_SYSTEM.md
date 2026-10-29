# PlayersZWZ UI Design System

This first pass records the visual rules visible in the supplied screens in `UI Screens/`. It is a working reference for the Flutter implementation; exact font family, color values, and interaction behavior should be confirmed against the editable design source if available.

## Visual direction

- Dark, high-contrast sports interface with black as the page canvas.
- Bright acid-lime is the signature accent for primary actions, selected states, sport marks, and important metrics.
- White carries headings and primary text; muted gray supports labels, hints, and inactive controls.
- Use rounded surfaces and compact, direct controls. Keep the map visually dominant on Explore.

## Color tokens

The values below are visual estimates from the 402 × 874 reference screenshots.

| Token | Approximate value | Use |
| --- | --- | --- |
| `background` | `#000000` | Main page canvas |
| `surface` | `#1C1C1C` | Inputs, cards, inactive chips |
| `surfaceElevated` | `#252525` | Raised overlays and selected card regions |
| `accent` | `#D7FF00` | Primary CTA, selected navigation, badges, highlights |
| `textPrimary` | `#FFFFFF` | Headings and important content |
| `textSecondary` | `#A6A6A6` | Supporting copy, placeholders, inactive items |
| `outline` | `#454545` | Dividers and subtle borders |
| `danger` | `#FF3B45` | Notification/count badge |

## Typography

- Use a clean, contemporary sans-serif. The screenshots do not identify the source font; treat the font family as an open choice until the source file is available.
- Screen titles use bold, large type (roughly 28–32 logical pixels).
- Section and card titles use semibold type (roughly 16–20 logical pixels).
- Body and button labels use regular to medium type (roughly 14–16 logical pixels).
- Supporting labels use roughly 12–14 logical pixels and muted gray.
- Keep text left-aligned except for centered authentication titles and CTA labels.

## Layout and shape

- References are portrait mobile layouts at 402 × 874 px.
- Typical page gutters are approximately 24 px; map and bottom navigation may extend closer to screen edges.
- Form fields are approximately 48–52 px tall, with 14–16 px corner radii and consistent vertical gaps.
- Cards use large rounded corners (approximately 20–24 px) and about 16 px internal padding.
- Chips and sport filters are pill-shaped. Selected filters use a lime outline or lime fill with dark text, depending on the component.
- Primary authentication buttons use a white pill-shaped track and a circular lime arrow affordance at the trailing edge.

## Components

### Authentication

- Center the brand mark above the page title.
- Use dark filled fields with muted placeholder text. Password fields include a trailing visibility control.
- Place the main submit action after the fields; separate alternate sign-in with a subtle “or” divider.
- Google sign-in is a dark full-width button with the Google mark and centered label.
- Keep account-switch links at the bottom of the form content.

### Explore map

- The map occupies the full screen behind the header, filters, venue/game markers, and floating controls.
- Use dark map styling so lime markers and light labels remain legible.
- Place sport filters beneath the page title. Map markers use dark rounded callouts with a lime sport icon, availability, and price.
- Keep recenter/location controls on the lower right and the persistent bottom navigation above the safe-area edge.
- Add visible Geoapify and data-source attribution in the map view, as required by the selected provider.

### Activity and profile

- Use a clear title row with a trailing notification or edit action.
- Switch between activity sections using compact pill tabs; highlight the selected tab with a lime border and text.
- Show activity details in dark cards with separators, participant summaries, and a lime action button.
- Profile uses a user identity row, a reliability score card, three compact statistic cards, and grouped preference controls.

### Bottom navigation

- Use a rounded, dark navigation capsule with four primary destinations.
- Inactive icons are gray; the active destination is lime.
- Preserve a large enough touch target for each destination and respect device safe areas.

## Interaction and accessibility

- Maintain strong contrast for white and lime text against black and dark surfaces.
- Give selected tabs and navigation items a shape/border cue in addition to color.
- Provide clear pressed, disabled, loading, validation, and error states for every form action.
- Keep controls comfortably tappable and ensure text can grow with system font scaling.
- Support reduced motion; map movement and transitions must not be required to understand state.

## Open decisions

- Confirm the original font family and exact color tokens from the editable UI source, if available.
- Confirm whether onboarding is skippable and how it transitions into profile setup.
- Confirm exact navigation destinations and selected/empty/error states for each screen.
- Confirm which icons are custom assets versus a standard icon family.
- Confirm map attribution placement against the final Geoapify map configuration.
