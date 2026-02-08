# Gather - Event Planning App

## Overview

Gather is a comprehensive event planning iOS app built with SwiftUI and SwiftData. It supports multi-function events (like weddings with Mehendi, Sangeet, Ceremony, Reception), unified guest management with per-function invitations, and budget tracking.

**Target**: iOS 17+
**Framework**: SwiftUI + SwiftData
**Architecture**: MVVM-lite with Services

---

## App Structure

### Navigation (4 Main Tabs)

| Tab | View | Purpose |
|-----|------|---------|
| Going | `GoingView.swift` | Events user is attending as a guest |
| My Events | `MyEventsView.swift` | Events user is hosting |
| Explore | `ExploreView.swift` | Public event discovery with category filters |
| Profile | `ProfileView.swift` | User settings, preferences, developer tools |

### Entry Points

```
GatherApp.swift
└── ContentView.swift (checks auth)
    ├── AuthView.swift (if not authenticated)
    └── MainTabView.swift (if authenticated)
        ├── GoingView
        ├── MyEventsView
        ├── ExploreView
        └── ProfileView
```

---

## Data Models

### Core Models (`Gather/Core/Models/`)

#### Event.swift
```swift
@Model class Event {
    var id: UUID
    var title: String
    var eventDescription: String?
    var startDate: Date
    var endDate: Date?
    var location: EventLocation?      // Codable struct
    var capacity: Int?
    var privacy: EventPrivacy         // .publicEvent, .unlisted, .inviteOnly
    var category: EventCategory       // .wedding, .party, .office, etc.
    var enabledFeaturesRaw: [String]  // Stored as strings for SwiftData
    var hostId: UUID

    @Relationship(deleteRule: .cascade) var guests: [Guest]
    @Relationship(deleteRule: .cascade) var functions: [EventFunction]
    @Relationship(deleteRule: .cascade) var comments: [Comment]

    // Computed
    var enabledFeatures: Set<EventFeature>
    var hasFunctions: Bool
    var hasGuestManagement: Bool
    var hasBudget: Bool
    var attendingCount: Int
    var isUpcoming: Bool
}
```

#### EventFunction.swift
```swift
@Model class EventFunction {
    var id: UUID
    var name: String                  // "Mehendi", "Sangeet", "Ceremony"
    var functionDescription: String?
    var date: Date
    var endTime: Date?
    var location: EventLocation?
    var dressCode: DressCode?         // .casual, .formal, .blackTie, etc.
    var sortOrder: Int
    var eventId: UUID

    @Relationship(deleteRule: .cascade) var invites: [FunctionInvite]
}
```

#### Guest.swift
```swift
@Model class Guest {
    var id: UUID
    var name: String
    var email: String?
    var phone: String?
    var status: RSVPStatus            // .pending, .attending, .declined, .maybe
    var plusOneCount: Int
    var role: GuestRole               // .guest, .vip, .cohost, .vendor
    var userId: UUID?                 // Links to User if they have the app
    var notes: String?
}
```

#### FunctionInvite.swift
```swift
@Model class FunctionInvite {
    var id: UUID
    var guestId: UUID
    var functionId: UUID
    var inviteStatus: InviteStatus    // .notSent, .sent, .responded
    var sentAt: Date?
    var sentVia: InviteChannel?       // .whatsapp, .sms, .email, .copied
    var response: RSVPResponse?       // .yes, .no, .maybe
    var partySize: Int
    var notes: String?
    var respondedAt: Date?
}
```

#### Ticket.swift (Ticketing System)
```swift
@Model class TicketTier {
    var id: UUID
    var name: String                  // "VIP", "General Admission"
    var tierDescription: String?
    var price: Decimal                // 0 for free
    var capacity: Int
    var soldCount: Int
    var minPerOrder: Int              // Default: 1
    var maxPerOrder: Int              // Default: 10
    var perks: [String]               // ["Front row seating", "Meet & greet"]
    var salesStartDate: Date?
    var salesEndDate: Date?
    var isHidden: Bool                // For promo-only tiers

    // Computed
    var isFree: Bool
    var isAvailable: Bool
    var isSoldOut: Bool
    var remainingCount: Int
    var formattedPrice: String
    var salesStatus: SalesStatus      // .upcoming, .onSale, .soldOut, .ended
}

@Model class Ticket {
    var id: UUID
    var ticketNumber: String          // "TKT-ABC1234"
    var eventId: UUID
    var tierId: UUID
    var guestName: String
    var guestEmail: String
    var quantity: Int
    var unitPrice: Decimal
    var totalPrice: Decimal
    var discountAmount: Decimal
    var promoCodeUsed: String?
    var paymentStatus: PaymentStatus  // .pending, .completed, .refunded
    var paymentMethod: PaymentMethod? // .applePay, .card, .free
    var qrCodeData: String            // For QR code generation
    var isCheckedIn: Bool
}

@Model class PromoCode {
    var id: UUID
    var code: String                  // "EARLYBIRD20"
    var eventId: UUID
    var discountType: DiscountType    // .percentage, .fixed
    var discountValue: Decimal        // 20 for 20% or 10.00 for $10 off
    var usageLimit: Int?
    var usageCount: Int
    var validFrom: Date?
    var validUntil: Date?
    var isActive: Bool
}

@Model class WaitlistEntry {
    var id: UUID
    var eventId: UUID
    var tierId: UUID?                 // Specific tier or general
    var email: String
    var name: String?
    var userId: UUID?
    var position: Int
    var notifiedAt: Date?
}
```

### Enums

| Enum | Values |
|------|--------|
| `EventCategory` | wedding, party, office, conference, concert, meetup, custom |
| `EventFeature` | functions, guestManagement, ticketing, budget, seating, schedule |
| `DressCode` | casual, smartCasual, cocktail, formal, blackTie, traditional, custom |
| `InviteStatus` | notSent, sent, responded |
| `RSVPResponse` | yes, no, maybe |
| `RSVPStatus` | pending, attending, declined, maybe, waitlisted |
| `InviteChannel` | whatsapp, sms, email, inAppLink, copied |
| `GuestRole` | guest, vip, cohost, vendor |
| `EventPrivacy` | publicEvent, unlisted, inviteOnly |
| `PaymentStatus` | pending, processing, completed, failed, refunded, cancelled |
| `PaymentMethod` | applePay, card, upi, bankTransfer, free |
| `DiscountType` | percentage, fixed |

---

## Feature Architecture

### EventDetailView (Tabbed Interface)

```
EventDetailView.swift
├── Header (Hero image, title, category badge)
├── Segmented Control (Overview | Functions | Guests | Budget)
└── Tab Content
    ├── OverviewTab.swift
    │   ├── Quick Actions (Add Guest, Send Invites, Share)
    │   ├── RSVP Summary Card (progress bars)
    │   ├── Date/Time Section
    │   ├── Location Section (with map)
    │   ├── Functions Timeline
    │   └── Recent RSVPs
    │
    ├── FunctionsTab.swift
    │   ├── FunctionCard.swift (summary cards)
    │   ├── AddFunctionSheet.swift
    │   └── FunctionDetailSheet.swift (with RSVP button for guests)
    │
    ├── GuestsTab.swift
    │   ├── Status Summary Bar (filter pills with counts)
    │   ├── Search Bar
    │   ├── ImprovedGuestCard (avatar, status ring, function chips)
    │   └── Selection Mode (batch send invites)
    │
    └── BudgetTab.swift
        ├── Budget summary
        ├── Categories with function tags
        └── Expense tracking
```

### Invite Flow

```
SendInvitesSheet.swift (Single-page design)
├── Quick Actions: [All Guests] [Not Sent] [Custom]
├── Guest Selection: LazyVGrid of tappable chips
├── Function Selection: Checkboxes (auto-selects all)
├── Channel Selection: WhatsApp | SMS | Email | Copy
└── Send Button: "Send X Invites"
    └── InviteService handles actual sending
```

### RSVP Flow

```
For Events WITHOUT functions:
└── RSVPSheet.swift (event-level RSVP)
    └── ManageRSVPSheet.swift (edit existing RSVP)

For Events WITH functions:
└── FunctionRSVPSheet.swift (per-function RSVP)
    ├── Response: Yes / No / Maybe
    ├── Party Size picker
    └── Notes field
```

### RSVP Button States (EventDetailView)
```
User has NOT responded:
└── Shows "RSVP" button → Opens RSVPSheet

User HAS responded:
└── Shows status (Attending/Maybe/Declined) + "Manage" button
    └── Opens ManageRSVPSheet
        ├── Free events: Can modify/cancel
        └── Paid events: Can only "Request Cancellation"
```

### Ticketing Flow

```
TicketPurchaseSheet.swift (Single-page design)
├── Progress Bar (Select → Details → Pay → Confirm)
├── Tier Selection (cards with price, perks, availability)
├── Quantity Stepper
├── Promo Code Input (with validation)
├── Order Summary
│   ├── Subtotal
│   ├── Discount (if promo applied)
│   ├── Group Discount (5+ = 10%, 10+ = 15%, 20+ = 20%)
│   └── Total
├── Guest Info (Name, Email)
└── Payment Selection
    ├── Apple Pay (demo)
    └── Card (demo with fake processing)

TicketConfirmationView.swift
├── Success Animation
├── Ticket Card (event info, QR code)
├── Action Buttons
│   ├── Add to Calendar (EventKit integration)
│   ├── Add to Wallet (placeholder)
│   └── Share
└── Done Button
```

### Waitlist Flow (Sold Out Events)
```
WaitlistSheet.swift
├── Join Form (Name, Email)
├── Position Display (#X in waitlist)
└── Already On Waitlist view
    └── Leave Waitlist option
```

---

## Services (`Gather/Core/Services/`)

### AuthManager.swift
- `@MainActor` ObservableObject
- Handles Apple Sign In, Google Sign In, Email Magic Link
- `signInAsDemo()` for testing
- Stores userId in UserDefaults

### InviteService.swift
- Singleton (`InviteService.shared`)
- `sendViaWhatsApp/SMS/Email(guest:event:functions:)`
- `copyInviteLink(guest:event:)`
- `createFunctionInvites(for:functions:modelContext:)`
- `markInviteSent(invite:channel:modelContext:)`

### NotificationService.swift
- Push notification scheduling
- RSVP notifications to host
- Event reminders

### DemoDataService.swift
- `loadDemoData(modelContext:hostId:)` - Creates sample events
- `resetAllData(modelContext:)` - Clears all data
- Creates both hosted events and events user is attending

---

## Design System (`Gather/DesignSystem/`)

### Colors.swift
```swift
// Semantic Colors
Color.gatherPrimaryText      // .label
Color.gatherSecondaryText    // .secondaryLabel
Color.gatherTertiaryText     // .tertiaryLabel
Color.gatherBackground       // .systemBackground
Color.gatherSecondaryBackground
Color.gatherTertiaryBackground

// Brand Colors
Color.accentPurpleFallback   // #7C3AED
Color.accentPinkFallback     // #EC4899

// Extended Palette
Color.warmCoral              // #FF6B6B
Color.sunshineYellow         // #FBBF24
Color.mintGreen              // #34D399
Color.neonBlue               // #3B82F6
Color.softLavender           // #A78BFA

// RSVP Status Colors
Color.rsvpYesFallback        // Green (attending)
Color.rsvpNoFallback         // Red (declined)
Color.rsvpMaybeFallback      // Orange (maybe)

// Glass Border Colors
Color.glassBorderTop         // White 30% opacity
Color.glassBorderBottom      // White 10% opacity

// Gradients
LinearGradient.gatherAccentGradient  // Purple → Pink
LinearGradient.heroOverlay           // Clear → Black for hero text
LinearGradient.categoryGradient(for:)      // Category-specific
LinearGradient.categoryGradientVibrant(for:)
LinearGradient.cardGradient(for:)          // Light tint for cards
Color.forCategory(_:)                      // Solid category color
```

### Glassmorphism System
```swift
// Glass card modifier (used throughout the app)
.glassCard()
// Applies: .ultraThinMaterial + rounded corners + glass border gradient + shadow

// Glass border pattern (for pills, chips, search bars)
.overlay(
    Capsule()
        .strokeBorder(
            LinearGradient(
                colors: [Color.glassBorderTop, Color.glassBorderBottom],
                startPoint: .top, endPoint: .bottom
            ),
            lineWidth: 0.5
        )
)

// CategoryMeshBackground (iOS 18 MeshGradient with fallback)
CategoryMeshBackground(category: .wedding)
// Animated 3x3 mesh gradient using category colors, iOS 17 falls back to LinearGradient

// Avatar components
AvatarStack(names: [...], maxDisplay: 5, size: 32)  // Overlapping avatar circles
GradientRing(color: .purple, lineWidth: 3)           // Ring modifier for avatars

// Button styles
CardPressStyle()  // Scale 0.97 + subtle rotation3D on press

// Animations
.bouncyAppear(delay: 0.05)     // Spring scale-in animation
.contentTransition(.numericText())  // Animated number changes
```

### Typography.swift
```swift
GatherFont.largeTitle  // 34pt Bold
GatherFont.title       // 28pt Bold
GatherFont.title2      // 22pt Semibold
GatherFont.title3      // 20pt Semibold
GatherFont.headline    // 17pt Semibold
GatherFont.body        // 17pt Regular
GatherFont.callout     // 16pt Regular
GatherFont.caption     // 12pt Regular
```

### Spacing.swift
```swift
Spacing.xxs  = 4
Spacing.xs   = 8
Spacing.sm   = 12
Spacing.md   = 16
Spacing.lg   = 24
Spacing.xl   = 32
Spacing.xxl  = 48

CornerRadius.sm   = 8
CornerRadius.md   = 12
CornerRadius.lg   = 16
CornerRadius.card = 20  // For hero cards and featured content

AvatarSize.sm = 32
AvatarSize.md = 40
AvatarSize.lg = 56
```

---

## File Structure

```
Gather/
├── App/
│   ├── GatherApp.swift          # Entry point, SwiftData schema
│   ├── ContentView.swift        # Auth routing
│   └── MainTabView.swift        # Tab navigation
│
├── Core/
│   ├── Models/
│   │   ├── Event.swift
│   │   ├── EventFunction.swift
│   │   ├── FunctionInvite.swift
│   │   ├── Guest.swift
│   │   ├── User.swift
│   │   ├── EventCategory.swift  # EventCategory, EventFeature enums
│   │   ├── Budget.swift
│   │   └── Comment.swift
│   │
│   └── Services/
│       ├── AuthManager.swift
│       ├── InviteService.swift
│       ├── NotificationService.swift
│       └── DemoDataService.swift
│
├── DesignSystem/
│   ├── Colors.swift
│   ├── Typography.swift
│   ├── Spacing.swift
│   └── Components/
│       ├── GatherButton.swift
│       ├── GatherTextField.swift
│       └── EventCard.swift
│
└── Features/
    ├── Auth/Views/
    │   └── AuthView.swift
    │
    ├── Going/Views/
    │   └── GoingView.swift
    │
    ├── Explore/Views/
    │   └── ExploreView.swift
    │
    ├── Profile/Views/
    │   └── ProfileView.swift
    │
    ├── Events/
    │   ├── List/Views/
    │   │   ├── MyEventsView.swift
    │   │   └── CreateEventView.swift
    │   │
    │   └── Detail/Views/
    │       ├── EventDetailView.swift
    │       ├── Tabs/
    │       │   ├── OverviewTab.swift
    │       │   ├── FunctionsTab.swift
    │       │   ├── GuestsTab.swift
    │       │   └── BudgetTab.swift
    │       ├── Functions/
    │       │   ├── FunctionCard.swift
    │       │   ├── AddFunctionSheet.swift
    │       │   └── FunctionDetailSheet.swift
    │       ├── Guests/
    │       │   ├── GuestRowWithFunctions.swift
    │       │   ├── GuestFilterBar.swift
    │       │   └── AddGuestSheet.swift
    │       └── Invites/
    │           └── SendInvitesSheet.swift
    │
    ├── RSVP/Views/
    │   ├── RSVPSheet.swift
    │   ├── FunctionRSVPSheet.swift
    │   └── ManageRSVPSheet.swift
    │
    └── Tickets/Views/
        ├── TicketPurchaseSheet.swift
        ├── TicketConfirmationView.swift
        └── WaitlistSheet.swift
```

---

## Key Patterns

### SwiftData Relationships
```swift
// Cascade delete - when event deleted, guests deleted too
@Relationship(deleteRule: .cascade) var guests: [Guest]
```

### Feature Flags via Enums
```swift
// Event categories define default features
EventCategory.wedding.defaultFeatures // [.functions, .guestManagement, .budget, .seating]

// Features can be toggled per event
event.enabledFeatures.contains(.functions)
event.hasFunctions // Computed shorthand
```

### Conditional Tab Visibility
```swift
// EventDetailView only shows relevant tabs
private var visibleTabs: [EventDetailTab] {
    EventDetailTab.allCases.filter { $0.isVisible(for: event) }
}
```

### Host vs Guest Views
```swift
// Check if current user is host
private var isHost: Bool {
    event.hostId == authManager.currentUser?.id
}

// Show different UI based on role
if isHost {
    // Show edit controls, send invites, etc.
} else {
    // Show RSVP button
}
```

---

## Deep Links

| URL | Action |
|-----|--------|
| `gather://event/{eventId}` | Open event detail |
| `gather://rsvp/{eventId}/{guestId}` | Open RSVP flow for guest |
| `gather://function/{functionId}` | Open function detail |

---

## Testing

### Demo Mode
1. Launch app → Tap "Demo Sign In"
2. Go to Profile → "Load Demo Data"
3. Creates:
   - 3 hosted events (Wedding, Birthday, Conference)
   - 3 attending events (Friend's Wedding, Office Party, Concert)
   - Sample guests with varied RSVP statuses
   - Function invites with mixed sent/responded states

### Reset Data
Profile → "Reset All Data" clears everything

---

## Common Tasks

### Add a New Event Category
1. Add case to `EventCategory` enum in `EventCategory.swift`
2. Add `displayName`, `icon`, `defaultFeatures`
3. Category automatically appears in Explore filters

### Add a New Feature Toggle
1. Add case to `EventFeature` enum
2. Add computed property to `Event.swift` (e.g., `hasNewFeature`)
3. Add conditional UI in `EventDetailView`

### Modify Guest Card Display
Edit `ImprovedGuestCard` in `GuestsTab.swift`:
- Status ring color in `statusColor`
- Function chips in `functionStatusRow`
- Avatar colors in `avatarColor`

### Change Invite Channels
Edit `InviteChannel` enum in `FunctionInvite.swift`:
- Add `icon`, `color`, `displayName`, `shortName` properties
- Implement sending logic in `InviteService.swift`

---

## Dependencies

- **SwiftUI** - UI framework
- **SwiftData** - Persistence
- **MapKit** - Location maps in OverviewTab
- **AuthenticationServices** - Apple Sign In
- **No external packages** - All native frameworks

---

## Build & Run

```bash
# Build
xcodebuild -project Gather.xcodeproj -scheme Gather \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run on simulator
open -a Simulator
xcrun simctl boot "iPhone 17 Pro"
```

---

## Recent Additions (Feb 2026)

### Glassmorphism Design System Overhaul
- `.glassCard()` modifier: `.ultraThinMaterial` + gradient glass border + shadow
- `CategoryMeshBackground`: iOS 18 animated MeshGradient per category (fallback for iOS 17)
- Extended color palette: `warmCoral`, `sunshineYellow`, `mintGreen`, `neonBlue`, `softLavender`
- Glass border tokens: `glassBorderTop` / `glassBorderBottom`
- `AvatarStack` component with overlapping circles
- `GradientRing` modifier for avatar borders
- `CardPressStyle` button style (scale + rotation3D)
- `.bouncyAppear()` staggered spring animations
- `.contentTransition(.numericText())` on all animated counts

### UI Refresh (All Tabs)
- **GoingView**: Glass filter pills, CategoryMeshBackground hero card, AvatarStack attendees
- **MyEventsView**: Glass tab bar, QuickStatBubble cards, category-tinted MyEventCards
- **ExploreView**: Glass search bar, category chips, featured/happening-soon cards with mesh backgrounds
- **ProfileView**: Complete redesign from List to ScrollView, ProfileStatCard, ProfileMenuItem with colored icons
- **EventDetailView**: 300pt hero with CategoryMeshBackground + rounded bottom corners, labeled floating tab bar with glass border
- **OverviewTab**: Glass quick action cards, RSVP summary card, timeline cards, recent RSVP rows
- **FunctionsTab**: Timeline connector with gradient dots between function cards
- **GuestsTab**: Glass search bar, glass status pills, glass guest cards
- **BudgetTab**: All cards converted to `.glassCard()`, glass filter chips

### Ticketing System
- Multiple ticket tiers with pricing, capacity, perks
- Demo payment flow (Apple Pay + Card)
- QR code tickets with ticket numbers
- Promo codes with percentage/fixed discounts
- Group discounts (5+ = 10%, 10+ = 15%, 20+ = 20%)
- Waitlist for sold-out events

### Improved RSVP Experience
- Smart RSVP button states (shows status when already responded)
- ManageRSVPSheet for editing existing RSVPs
- Free events: full edit/cancel capability
- Paid tickets: request cancellation (host approval)

### Streamlined Invite Flow
- Single-page design (replaced 4-step wizard)
- Quick action buttons (All, Not Sent, Custom)
- Guest chips in LazyVGrid for selection
- Inline function/channel selection

### Enhanced Guest List
- Status pills with counts at top
- ImprovedGuestCard with avatar + status ring
- Function status chips with abbreviations
- Better filter system

---

## Production Payment Architecture (Stripe Connect)

> **Status**: Planning phase. The current ticketing system uses demo payment simulation.
> This section documents the architecture for replacing it with real Stripe Connect payments.

### Why Stripe Connect

Gather is a **marketplace** where hosts sell tickets to attendees. Stripe Connect handles:
- Splitting payments between Gather (platform fee) and hosts (event revenue)
- Regulatory compliance (KYC, tax reporting, PCI DSS)
- Multi-currency support
- Automated payouts to host bank accounts

### Architecture Overview

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐
│  iOS App    │────▶│  Gather API  │────▶│  Stripe Connect  │
│  (SwiftUI)  │◀────│  (Backend)   │◀────│  (Payment Rails) │
└─────────────┘     └──────────────┘     └──────────────────┘
       │                    │                      │
   PaymentSheet      Payment Intents          Connected
   (Stripe SDK)      Webhooks                 Accounts
                     Payout scheduling        (Host accounts)
```

### Account Types

| Role | Stripe Entity | Onboarding |
|------|--------------|------------|
| Gather (Platform) | Platform Account | One-time setup |
| Event Host | Connected Account (Express) | Stripe-hosted onboarding |
| Ticket Buyer | Customer (optional) | None required |

### Payment Flow

```
1. HOST ONBOARDING
   Host taps "Enable Payments" in event settings
   → App calls: POST /api/connect/onboarding
   → Backend creates Stripe Connected Account (Express)
   → Returns Stripe-hosted onboarding URL
   → Host completes KYC in Safari/SFSafariViewController
   → Webhook: account.updated → Mark host as payment-ready

2. TICKET PURCHASE
   Buyer taps "Get Tickets" → TicketPurchaseSheet
   → App calls: POST /api/payments/create-intent
     Body: { eventId, tiers: [{tierId, qty}], promoCode? }
   → Backend:
     a. Validates tier availability, promo code
     b. Calculates total (with group/promo discounts)
     c. Creates Stripe PaymentIntent:
        - amount: total in cents
        - application_fee_amount: platform fee (e.g., 5% + $0.50)
        - transfer_data.destination: host's connected account
        - metadata: { eventId, tiers, userId }
     d. Returns: { clientSecret, paymentIntentId }
   → App presents Stripe PaymentSheet with clientSecret
   → Buyer pays (Apple Pay, Card, etc.)

3. PAYMENT CONFIRMATION
   Stripe webhook: payment_intent.succeeded
   → Backend:
     a. Creates Ticket records (same as current demo flow)
     b. Updates TicketTier.soldCount
     c. Sends confirmation email
     d. Sends push notification to host
     e. Creates Guest record if not exists
   → App polls or receives push → Shows TicketConfirmationView

4. HOST PAYOUT
   Stripe automatically transfers to host's bank account
   Default: 2-day rolling basis (configurable)
   Platform fee retained by Gather's Stripe account
```

### Fee Structure

```
Ticket Price: $50.00
├── Stripe Processing: ~$1.75 (2.9% + $0.30)  ← Stripe takes this
├── Gather Platform Fee: $3.00 (5% + $0.50)    ← Gather revenue
└── Host Receives: $45.25                       ← Auto-transferred
```

### Backend Requirements

```
New API Endpoints:

POST   /api/connect/onboarding          → Create Connected Account + onboarding link
GET    /api/connect/status               → Check host payment readiness
POST   /api/payments/create-intent       → Create PaymentIntent for ticket purchase
POST   /api/payments/apply-promo         → Validate & calculate promo discount
POST   /api/payments/refund              → Process refund (host-initiated)
GET    /api/payments/history/:eventId    → Host's transaction history
POST   /api/webhooks/stripe              → Handle Stripe webhooks

Webhook Events to Handle:
- payment_intent.succeeded       → Create ticket, update counts
- payment_intent.payment_failed  → Notify buyer, release inventory
- charge.refunded                → Update ticket status, notify buyer
- account.updated                → Update host payment readiness
- payout.paid                    → Notify host of deposit
- payout.failed                  → Alert host of payout issue
```

### iOS App Changes

```swift
// New dependency
import StripePaymentSheet  // via SPM: stripe/stripe-ios

// PaymentService.swift (replaces demo simulation)
class PaymentService {
    static let shared = PaymentService()

    /// Create payment intent and return client secret
    func createPaymentIntent(
        eventId: UUID,
        tiers: [(tierId: UUID, quantity: Int)],
        promoCode: String?
    ) async throws -> PaymentIntentResponse

    /// Present Stripe PaymentSheet
    func presentPaymentSheet(
        clientSecret: String,
        merchantDisplayName: String
    ) async throws -> PaymentSheetResult

    /// Request refund (host action)
    func requestRefund(ticketId: UUID) async throws -> RefundResponse
}

// TicketPurchaseSheet changes:
// - Replace fake 2-second delay with real PaymentSheet
// - Add error handling for declined cards
// - Add retry logic for network failures
// - Keep free ticket flow as-is (no Stripe needed)

// ProfileView changes (for hosts):
// - Add "Payment Settings" menu item
// - Show payout schedule, connected account status
// - Link to Stripe Express Dashboard

// EventDetailView changes (for hosts):
// - Add revenue card in OverviewTab when ticketing enabled
// - Show real-time sales, fees, and net revenue
```

### Migration Strategy

```
Phase A: Backend Setup
  1. Set up Node.js/Express API (or serverless functions)
  2. Configure Stripe Connect platform account
  3. Implement webhook handlers
  4. Deploy to staging

Phase B: Host Onboarding
  1. Add "Enable Payments" flow in CreateEventView
  2. Integrate SFSafariViewController for Stripe onboarding
  3. Show payment readiness status in event settings
  4. Existing demo events continue to work (demo flag)

Phase C: Buyer Payment
  1. Add stripe-ios SDK via SPM
  2. Replace demo payment in TicketPurchaseSheet
  3. Free tickets bypass Stripe entirely
  4. Add PaymentSheet presentation
  5. Handle success/failure states

Phase D: Host Dashboard
  1. Revenue overview in OverviewTab
  2. Transaction history
  3. Refund management
  4. Payout tracking (link to Stripe Express Dashboard)

Phase E: Production Launch
  1. End-to-end testing with test mode
  2. Switch to Stripe live keys
  3. App Store review (in-app purchases exemption for physical events)
  4. Monitor webhooks and payout health
```

### App Store Considerations

- **Physical event tickets are exempt** from Apple's 30% in-app purchase requirement
- Stripe handles PCI compliance for card data
- Apple Pay via Stripe (not Apple's native IAP) is permitted for physical goods/services
- Must include refund policy in app and App Store listing

---

## Future Enhancements

- [ ] CloudKit sync for multi-device
- [ ] Actual WhatsApp/SMS integration (currently opens compose)
- [x] ~~Real payment processing (Stripe)~~ → Architecture planned (see above)
- [ ] Apple Wallet pass generation
- [ ] Seating chart feature
- [ ] Schedule/itinerary builder
- [ ] Photo gallery per event
- [ ] Vendor management
- [ ] Budget analytics/reports
- [ ] Check-in scanning (QR code reader for hosts)
