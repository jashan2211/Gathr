# Gather (Gathr) - Production Launch Checklist

> Steps that **cannot** be done in Claude Code. Complete these in order to make the app fully functional at production level.

---

## Phase 1: Apple Developer Portal Setup

### 1.1 App ID & Capabilities
- [ ] Sign in to [Apple Developer Portal](https://developer.apple.com/account)
- [ ] Register App ID: `ca.thebighead.gathr`
- [ ] Enable capabilities:
  - **Sign in with Apple** (already in entitlements)
  - **Push Notifications** (for APNs)
  - **Associated Domains** (for Universal Links)
  - **Apple Pay** (for Stripe Apple Pay integration)
  - **App Groups** (if sharing data with extensions later)

### 1.2 APNs Key (Push Notifications)
- [ ] Go to **Keys** > Create a new key
- [ ] Enable **Apple Push Notifications service (APNs)**
- [ ] Download the `.p8` key file (you only get ONE download)
- [ ] Note the **Key ID** and **Team ID** - you'll need these for Firebase/your backend
- [ ] Store the `.p8` file securely (never commit to git)

### 1.3 Apple Pay Merchant ID
- [ ] Go to **Identifiers** > **Merchant IDs**
- [ ] Create: `merchant.ca.thebighead.gathr`
- [ ] You'll configure this in Stripe Dashboard later (Stripe handles Apple Pay via their SDK)

### 1.4 Provisioning Profiles
- [ ] Create **Development** profile for `ca.thebighead.gathr`
- [ ] Create **Distribution (App Store)** profile for `ca.thebighead.gathr`
- [ ] Download and install both in Xcode

### 1.5 Associated Domains (Universal Links)
- [ ] In the App ID configuration, enable **Associated Domains**
- [ ] You'll add `applinks:gathr.thebighead.ca` (or your chosen domain) in Xcode entitlements later

---

## Phase 2: Backend Setup

Choose ONE backend approach. Firebase is recommended for fastest time-to-market.

### Option A: Firebase (Recommended)

#### 2A.1 Create Firebase Project
- [ ] Go to [Firebase Console](https://console.firebase.google.com)
- [ ] Create project: `gathr-production`
- [ ] Add iOS app with bundle ID: `ca.thebighead.gathr`
- [ ] Download `GoogleService-Info.plist` and add to Xcode project (it's gitignored)

#### 2A.2 Firebase Authentication
- [ ] Go to **Authentication** > **Sign-in method**
- [ ] Enable **Apple** provider
  - Paste your Services ID and private key from Apple Developer
- [ ] Enable **Google** provider
  - Download updated `GoogleService-Info.plist`
- [ ] Enable **Email/Password** provider (with email verification)
- [ ] Optional: Enable **Email Link (Passwordless)** for magic links

#### 2A.3 Cloud Firestore
- [ ] Create Firestore database (start in **production mode**)
- [ ] Set up security rules:
  ```
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      // Users can read/write their own data
      match /users/{userId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      // Events: hosts can write, invited users can read
      match /events/{eventId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == resource.data.hostId;
      }
      // Add more granular rules for guests, tickets, etc.
    }
  }
  ```
- [ ] Create indexes for common queries (events by hostId, guests by eventId, etc.)

#### 2A.4 Cloud Functions (for server-side logic)
- [ ] Initialize Firebase Functions (Node.js)
- [ ] Deploy webhook handlers for Stripe
- [ ] Deploy push notification triggers
- [ ] Deploy invite link generators

#### 2A.5 Firebase Cloud Messaging (Push Notifications)
- [ ] Upload APNs key (.p8) from Phase 1.2
- [ ] Enter Key ID and Team ID
- [ ] Test with a push notification from the console

#### 2A.6 Firebase Crashlytics
- [ ] Enable Crashlytics in Firebase Console
- [ ] The SDK integration has been prepared in code
- [ ] Verify crash reports appear after first app crash

#### 2A.7 Firebase Analytics
- [ ] Analytics is automatically enabled with Firebase SDK
- [ ] Set up custom events in the console for funnel tracking
- [ ] Create audiences for engagement segmentation

### Option B: Supabase (Alternative)
- [ ] Create project at [supabase.com](https://supabase.com)
- [ ] Set up PostgreSQL tables matching SwiftData models
- [ ] Configure Row Level Security (RLS) policies
- [ ] Set up Supabase Auth with Apple/Google providers
- [ ] Use Supabase Edge Functions for webhooks

---

## Phase 3: Stripe Connect Setup (Payments)

### 3.1 Stripe Account
- [ ] Sign up at [stripe.com](https://stripe.com)
- [ ] Complete business verification (KYC)
- [ ] Note your **Publishable Key** and **Secret Key**

### 3.2 Enable Stripe Connect
- [ ] Go to **Connect** > **Get started**
- [ ] Choose **Express** account type (hosts will use Stripe-hosted onboarding)
- [ ] Configure platform settings:
  - Platform name: `Gathr`
  - Platform fee: 5% + $0.50 (or your chosen fee structure)
  - Payout schedule: 2-day rolling (or configure per your preference)

### 3.3 Configure Apple Pay in Stripe
- [ ] Go to **Settings** > **Payment methods** > **Apple Pay**
- [ ] Upload your Apple Pay certificate from Phase 1.3
- [ ] Verify the domain for Apple Pay on web (if applicable)

### 3.4 Set Up Webhooks
- [ ] Go to **Developers** > **Webhooks**
- [ ] Add endpoint: `https://your-backend.com/api/webhooks/stripe`
- [ ] Subscribe to events:
  - `payment_intent.succeeded`
  - `payment_intent.payment_failed`
  - `charge.refunded`
  - `account.updated` (Connect)
  - `payout.paid` (Connect)
  - `payout.failed` (Connect)
- [ ] Note the **Webhook Signing Secret**

### 3.5 Test Mode
- [ ] Use test keys for development (`pk_test_...`, `sk_test_...`)
- [ ] Test with Stripe test card numbers:
  - Success: `4242 4242 4242 4242`
  - Decline: `4000 0000 0000 0002`
  - 3D Secure: `4000 0027 6000 3184`
- [ ] Verify webhooks work with `stripe listen --forward-to localhost:PORT`

### 3.6 Go Live
- [ ] Switch to live keys (`pk_live_...`, `sk_live_...`)
- [ ] Update webhook endpoint to production URL
- [ ] Verify first real transaction

---

## Phase 4: Domain & Universal Links

### 4.1 Domain Setup
- [ ] Set up domain: `gathr.thebighead.ca` (or your chosen domain)
- [ ] Point DNS to your web hosting / backend

### 4.2 Apple App Site Association (AASA)
- [ ] Host AASA file at: `https://gathr.thebighead.ca/.well-known/apple-app-site-association`
  ```json
  {
    "applinks": {
      "apps": [],
      "details": [
        {
          "appID": "TEAM_ID.ca.thebighead.gathr",
          "paths": [
            "/event/*",
            "/rsvp/*",
            "/invite/*",
            "/ticket/*"
          ]
        }
      ]
    }
  }
  ```
- [ ] Serve with `Content-Type: application/json` (no redirects, HTTPS only)
- [ ] Validate at [Apple AASA Validator](https://search.developer.apple.com/appsearch-validation-tool/)

### 4.3 Web Fallback Pages
- [ ] Create web pages for when links are opened without the app:
  - `/event/{id}` - Event preview with "Open in Gathr" button + App Store link
  - `/rsvp/{eventId}/{guestId}` - RSVP web form (fallback)
  - `/invite/{code}` - Invite landing page

---

## Phase 5: Legal & Compliance

### 5.1 Privacy Policy
- [ ] Verify `https://thebighead.ca/gathr/privacy` is live and accessible
- [ ] Must include:
  - What data you collect (name, email, phone, contacts, calendar, location)
  - How you use it (event management, invitations, ticketing)
  - Third-party services (Stripe, Firebase, Apple)
  - Data retention period
  - How users can delete their data
  - Contact information for privacy inquiries
  - GDPR rights (if serving EU users): access, rectification, erasure, portability
  - CCPA rights (if serving California users)

### 5.2 Terms of Service
- [ ] Verify `https://thebighead.ca/gathr/terms` is live and accessible
- [ ] Must include:
  - Acceptable use policy
  - Ticket refund policy (important for Stripe Connect)
  - Host responsibilities
  - Platform liability limitations
  - Dispute resolution
  - Account termination terms

### 5.3 Refund Policy
- [ ] Create refund policy page (required for ticketed events)
- [ ] Define: cancellation window, refund processing time, non-refundable fees
- [ ] This must be visible to ticket buyers before purchase

---

## Phase 6: App Store Connect

### 6.1 Create App Listing
- [ ] Sign in to [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Create new app:
  - Name: `Gathr`
  - Bundle ID: `ca.thebighead.gathr`
  - SKU: `gathr-ios`
  - Primary language: English

### 6.2 App Information
- [ ] Category: **Social Networking** (primary), **Lifestyle** (secondary)
- [ ] Age Rating: 4+ (unless allowing mature event content)
- [ ] Privacy Policy URL: `https://thebighead.ca/gathr/privacy`
- [ ] License Agreement: Standard or custom

### 6.3 Pricing & Availability
- [ ] Price: **Free** (revenue from platform fees on ticket sales)
- [ ] Availability: Select countries/regions
- [ ] Pre-orders: Optional

### 6.4 App Privacy (Data Collection Labels)
- [ ] Fill out the App Privacy questionnaire based on PrivacyInfo.xcprivacy:
  - **Contact Info**: Name, Email, Phone (Linked to Identity, for App Functionality)
  - **Identifiers**: User ID (Linked to Identity, for App Functionality)
  - **Purchases**: Purchase History (Linked to Identity, for App Functionality)
  - **Usage Data**: Product Interaction (Not Linked, for Analytics)
  - Data NOT used for tracking

### 6.5 Screenshots & Media
- [ ] Take screenshots on:
  - iPhone 6.9" (iPhone 16 Pro Max) - Required
  - iPhone 6.7" (iPhone 15 Plus) - Required
  - iPad Pro 13" - If supporting iPad
- [ ] Minimum 3 screenshots, recommended 6-10
- [ ] Capture key flows: Event creation, Guest management, Ticketing, RSVP, Explore
- [ ] Optional: Create an App Preview video (15-30 seconds)

### 6.6 App Review Notes
- [ ] Provide demo account credentials for Apple reviewer
- [ ] Explain the ticketing system (physical events are exempt from IAP requirement)
- [ ] Note: "This app facilitates ticket sales for physical, real-world events. Per App Store Review Guideline 3.1.3(e), in-app purchase is not required for physical goods and services delivered outside of the app."

### 6.7 Submit for Review
- [ ] Archive the app in Xcode (Product > Archive)
- [ ] Upload to App Store Connect via Xcode Organizer
- [ ] Select build in App Store Connect
- [ ] Submit for review
- [ ] Typical review time: 24-48 hours

---

## Phase 7: Post-Launch Monitoring

### 7.1 Crash Monitoring
- [ ] Monitor Crashlytics/Sentry dashboard daily for the first week
- [ ] Set up Slack/email alerts for new crash types
- [ ] Fix crash-free rate target: >99.5%

### 7.2 Analytics Review
- [ ] Monitor daily active users (DAU) and retention
- [ ] Track key funnels:
  - Sign up > Create first event
  - Receive invite > RSVP
  - Browse event > Purchase ticket
- [ ] Set up weekly analytics review cadence

### 7.3 User Feedback
- [ ] Monitor App Store reviews and ratings
- [ ] Set up in-app feedback mechanism (ProfileView already has "Send Feedback")
- [ ] Create a support email: `support@thebighead.ca`

### 7.4 Performance
- [ ] Monitor app launch time (<2s target)
- [ ] Monitor memory usage with large guest lists
- [ ] Set up Xcode Organizer monitoring for battery/performance

---

## Quick Reference: Environment Variables & Keys

Store these securely (never in code or git):

| Key | Where to get it | Where to use it |
|-----|----------------|-----------------|
| Firebase `GoogleService-Info.plist` | Firebase Console | Xcode project (gitignored) |
| Stripe Publishable Key (`pk_live_...`) | Stripe Dashboard | iOS app config |
| Stripe Secret Key (`sk_live_...`) | Stripe Dashboard | Backend ONLY (never in app) |
| Stripe Webhook Secret (`whsec_...`) | Stripe Dashboard | Backend ONLY |
| APNs Key (`.p8` file) | Apple Developer Portal | Firebase/Backend |
| APNs Key ID | Apple Developer Portal | Firebase/Backend |
| Apple Team ID | Apple Developer Portal | Firebase/Backend/AASA |

---

## Timeline Estimate

| Phase | Estimated Effort |
|-------|-----------------|
| Phase 1: Apple Developer Portal | 1-2 hours |
| Phase 2: Backend Setup (Firebase) | 1-2 weeks |
| Phase 3: Stripe Connect | 3-5 days |
| Phase 4: Domain & Universal Links | 2-4 hours |
| Phase 5: Legal & Compliance | 1-2 days (with legal review) |
| Phase 6: App Store Connect | 2-4 hours + review wait |
| Phase 7: Post-Launch | Ongoing |

**Total to production-ready: ~3-4 weeks** (assuming Firebase + Stripe Connect backend work)
