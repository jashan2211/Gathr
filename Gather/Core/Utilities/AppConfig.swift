import Foundation

enum AppConfig {
    /// `true` in DEBUG builds, `false` in Release. Gates demo-only features.
    static var isDemoMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Privacy Policy URL
    static let privacyPolicyURL = URL(string: "https://thebighead.ca/gathr/privacy")!

    /// Terms of Service URL
    static let termsOfServiceURL = URL(string: "https://thebighead.ca/gathr/terms")!

    /// Support URL
    static let supportURL = URL(string: "https://thebighead.ca/gathr/support")!

    /// Contact Email
    static let contactEmail = "info@thebighead.ca"

    /// App Store URL (real listing — id 6758989661)
    static let appStoreURL = URL(string: "https://apps.apple.com/app/gathr-event-party-manager/id6758989661")!

    /// Web base for universal links (RSVP/event landing pages live here).
    /// Must stay in sync with the apple-app-site-association file hosted at
    /// https://thebighead.ca/.well-known/apple-app-site-association
    static let webBaseURL = URL(string: "https://thebighead.ca/gathr")!

    /// Whether real Apple Wallet pass generation is enabled.
    /// Requires an Apple Developer signing certificate + server-side .pkpass creation.
    /// When `false`, the app shows a demo wallet-style card with a "Save to Photos" option.
    static let walletPassEnabled = false
}
