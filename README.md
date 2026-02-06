# Gather - Event Planning & RSVP App

A modern, privacy-first iOS app for creating events and managing RSVPs. Built with SwiftUI and SwiftData.

## Features

- **Create Events**: Design beautiful event invitations with cover photos, location, and customizable privacy settings
- **RSVP Management**: Track guest responses with an intuitive flow (Going, Maybe, Can't Go)
- **Smart Invites**: Share via SMS, email, or link - guests can RSVP without the app
- **Guest Lists**: Import contacts, create groups, and manage guest metadata
- **Calendar Sync**: One-tap calendar integration with EventKit
- **Push Notifications**: RSVP confirmations and event reminders via APNs
- **Privacy First**: No analytics, minimal data collection, GDPR compliant

## Requirements

- iOS 17.0+
- Xcode 15.2+
- Swift 5.9+

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/gather-ios.git
cd gather-ios
```

### 2. Configure Signing

1. Open `Gather.xcodeproj` in Xcode
2. Select the Gather target
3. Go to Signing & Capabilities
4. Select your team and update the bundle identifier

### 3. Set Up CloudKit

1. In Xcode, select the Gather target
2. Go to Signing & Capabilities
3. Add CloudKit capability if not present
4. Create a CloudKit container: `iCloud.com.yourteam.gather`
5. Enable the following record types in CloudKit Dashboard:
   - GatherUser
   - GatherEvent
   - GatherGuest
   - GatherComment
   - GatherMedia

### 4. Set Up Firebase (Optional - for Google Sign-In)

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an iOS app with your bundle identifier
3. Download `GoogleService-Info.plist` and add it to the Gather target
4. Enable Google Sign-In in Firebase Authentication

### 5. Build and Run

```bash
# Using Xcode
open Gather.xcodeproj

# Or via command line
xcodebuild -scheme Gather -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Project Structure

```
Gather/
├── App/                    # App entry point and root views
├── Core/
│   ├── Models/            # SwiftData models
│   ├── Services/          # Business logic (Auth, CloudKit, etc.)
│   └── Utilities/         # Extensions and helpers
├── Features/
│   ├── Auth/              # Authentication flow
│   ├── Home/              # Home feed
│   ├── Events/            # Event creation, detail, list
│   ├── Guests/            # Contact management
│   ├── RSVP/              # RSVP flow
│   └── Profile/           # User settings
├── DesignSystem/
│   ├── Colors.swift       # Color tokens
│   ├── Typography.swift   # Font styles
│   ├── Spacing.swift      # Spacing scale
│   └── Components/        # Reusable UI components
└── Resources/             # Assets and localization
```

## Architecture

### MVVM + Repository Pattern

- **Models**: SwiftData models with computed properties
- **Views**: SwiftUI views with minimal logic
- **ViewModels**: ObservableObject classes handling business logic
- **Services**: Singleton services for cross-cutting concerns (Auth, CloudKit, Notifications)

### Data Layer

- **SwiftData**: Local persistence and offline support
- **CloudKit**: Sync and cloud storage
- **Firebase Auth**: Google Sign-In and email magic links (optional)

## Environment Variables

Create a `.env` file in the project root (not committed to git):

```bash
# Firebase (optional)
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id

# CloudKit Container
CLOUDKIT_CONTAINER=iCloud.com.yourteam.gather

# App Configuration
BUNDLE_IDENTIFIER=com.yourteam.gather
```

## Testing

### Unit Tests

```bash
xcodebuild test \
  -scheme Gather \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:GatherTests
```

### UI Tests

```bash
xcodebuild test \
  -scheme Gather \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:GatherUITests
```

## CI/CD

GitHub Actions workflow is configured in `.github/workflows/ci.yml`:

- **Build**: Validates project compiles on every push
- **Test**: Runs unit and UI tests
- **Artifacts**: Uploads test results

## Design System

### Colors

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| Accent | #7C3AED | #7C3AED | Primary actions, links |
| Accent Secondary | #EC4899 | #EC4899 | Gradients, highlights |
| Success | #10B981 | #10B981 | RSVP: Going |
| Warning | #F59E0B | #F59E0B | RSVP: Maybe |
| Destructive | #EF4444 | #EF4444 | RSVP: Can't Go, delete |

### Typography

Uses SF Pro with Dynamic Type support:

- **Large Title**: 34pt Bold
- **Title**: 28pt Bold
- **Title 2**: 22pt Semibold
- **Headline**: 17pt Semibold
- **Body**: 17pt Regular
- **Caption**: 12pt Regular

### Components

- `GatherButton`: Primary, secondary, ghost, destructive variants
- `GatherTextField`: Text input with validation states
- `GatherCard`: Rounded containers with shadows
- `EventCard`: Event preview cards
- `RSVPSheet`: Bottom sheet RSVP flow

## Deployment

### TestFlight

1. Archive the app: Product → Archive
2. Distribute to App Store Connect
3. Add to TestFlight for beta testing

### App Store

1. Complete App Store Connect listing
2. Upload screenshots (see APP_PLAN.md for suggestions)
3. Submit for review

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -m 'Add my feature'`
4. Push to branch: `git push origin feature/my-feature`
5. Open a pull request

## License

This project is private and proprietary.

## Support

For issues and feature requests, please open a GitHub issue.

---

Built with SwiftUI and love.
