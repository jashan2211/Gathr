# Prompt for Gemini — Improve the Look & Feel of "Gather"

I'm building an iOS app called **Gather** and I want your help improving its **look and feel** (visual design, UI polish, motion, hierarchy, delight). Below is full context. Please give me concrete, prioritized, actionable recommendations — not vague advice. Where helpful, suggest specific colors (hex), spacing, typography, component patterns, and animation ideas. Assume the developer can implement anything in SwiftUI.

---

## What the app is

Gather is an **event planning & RSVP app** (think Partiful / Luma / Eventbrite hybrid). Users create events, manage guest lists, send invites, track RSVPs, sell tickets, and split budgets. It specializes in **multi-function events** — e.g. a wedding with separate Mehendi, Sangeet, Ceremony, and Reception sub-events, each with its own date, location, dress code, and per-function RSVP.

- **Platform:** iOS 17+ (some iOS 18 features like MeshGradient with fallbacks)
- **Tech:** SwiftUI + SwiftData, Firebase auth (Google + Apple Sign-In)
- **Audience:** Hosts planning social events (weddings, parties, conferences, concerts, meetups, office events) and guests RSVPing to them.

## Navigation (4 main tabs)

1. **Going** — events the user is attending as a guest
2. **My Events** — events the user is hosting
3. **Explore** — public event discovery with category filters
4. **Profile** — settings, stats, preferences

Plus: an **Event Detail** screen with a tabbed interface (Overview / Functions / Guests / Budget), a 4-step **Create Event** wizard, **RSVP** sheets, a **Ticket Purchase** flow with QR confirmation, and an **Onboarding** flow.

## Current design language (already implemented)

The app currently uses a **glassmorphism** aesthetic:

- **Brand colors:** Purple `#7C3AED` → Pink `#EC4899` gradient as the primary accent.
- **Extended palette:** warm coral `#FF6B6B`, sunshine yellow `#FBBF24`, mint green `#34D399`, neon blue `#00D4FF`, neon pink `#FF2D55`, deep indigo `#310A65`, soft lavender `#C4B5FD`.
- **Per-category color theming:** each event category has its own gradient (wedding = rose/pink, party = purple, office = blue, conference = amber/gold, concert = red/coral, meetup = teal/green, custom = slate).
- **Glass cards:** `.ultraThinMaterial` + a subtle white gradient overlay + a 0.5pt white gradient border + soft shadow. Used everywhere for cards, pills, chips, search bars.
- **Animated mesh-gradient backgrounds** (`CategoryMeshBackground`) behind hero areas, colored per category, animating slowly (iOS 18 MeshGradient, LinearGradient fallback on iOS 17).
- **Typography:** SF Pro **Rounded** for titles (largeTitle 34pt bold, title 28pt bold, title2 22pt semibold, title3 20pt semibold), standard SF Pro for body/callout/caption. Dynamic Type supported.
- **Spacing scale:** 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64. Corner radii: 8 / 12 / 16 / 20 (cards) / 24 / 32 (pills).
- **Motion:** spring-based `bouncyAppear` (scale + fade in, staggered), `CardPressStyle` (scale 0.97 + subtle 3D rotation on press), `contentTransition(.numericText())` for animated counters, a `ConfettiView` for celebrations (e.g. successful RSVP/ticket purchase), shimmer skeleton loaders instead of spinners.
- **Avatars:** colored circle initials, overlapping `AvatarStack` for attendee previews, gradient status rings.
- Full **light & dark mode** support.

## Screen-by-screen current state

- **Going / My Events:** glass filter pills at top, a hero card with animated mesh-gradient background, event cards tinted by category, overlapping attendee avatars, quick-stat bubbles (My Events).
- **Explore:** glass search bar, horizontally scrolling category chips, "featured" and "happening soon" sections with mesh-gradient card backgrounds.
- **Event Detail:** 300pt hero with category mesh gradient and rounded bottom corners, a floating labeled tab bar with glass border, then tab content:
  - **Overview:** glass quick-action cards (Add Guest / Send Invites / Share), an RSVP summary card with progress bars, date/time section, location with a map, functions timeline, recent RSVPs.
  - **Functions:** vertical timeline with gradient connector dots between function cards.
  - **Guests:** status filter pills with counts, search bar, guest cards with avatar + colored status ring + per-function status chips, batch-select mode for sending invites.
  - **Budget:** glass summary cards, categories with function tags, expense rows.
- **Create Event:** 4-step wizard (details → category/features → functions → review).
- **Ticket Purchase:** single-page flow with progress bar (Select → Details → Pay → Confirm), tier cards with price/perks/availability, quantity stepper, promo code input, order summary with group discounts, Apple Pay / card (demo), then a confirmation screen with success animation + QR code ticket.
- **Profile:** ScrollView with profile header, stat cards, and menu items with colored icons.

## What I want from you

Please critique and improve the **look and feel**, covering:

1. **Overall visual identity** — Is glassmorphism + purple/pink the right direction for an event app in 2026, or does it feel dated/generic? What would make it feel more premium, distinctive, and emotionally "celebratory" without being cluttered? Suggest a refined color and material direction.
2. **Visual hierarchy & layout** — Where is the design likely too busy (too many gradients/glass layers competing)? Where should I add calm/whitespace? How to make the most important action on each screen unmistakable.
3. **Typography** — Is SF Pro Rounded everywhere a good call, or should headers use something with more character? Suggest a type pairing and a clear type scale with weights.
4. **Color & theming** — Is per-category gradient theming a strength or a source of inconsistency? How to keep brand cohesion while still differentiating categories. Accessibility/contrast concerns (especially yellow/amber on white, glass text legibility).
5. **Motion & delight** — Where to add or restrain animation. Micro-interactions that would make RSVPing and creating an event feel joyful. Is confetti overused/underused?
6. **Component polish** — Specific upgrades to cards, buttons, pills/chips, the tab bar, sheets, empty states, and loading states.
7. **Modern iOS patterns** — Anything I should adopt from current iOS design trends (e.g. depth, fluid materials, large expressive type, interactive widgets, Live Activities for live events) that fits this app.
8. **Top 10 prioritized changes** — End with a ranked list of the 10 highest-impact, lowest-effort look-and-feel improvements I should do first.

Be specific and opinionated. If you'd design a particular screen differently, describe the layout.
