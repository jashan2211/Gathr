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
    static let privacyPolicyURL = URL(string: "https://thebighead.ca/privacy")!

    /// Terms of Service URL
    static let termsOfServiceURL = URL(string: "https://thebighead.ca/terms")!

    /// Support URL
    static let supportURL = URL(string: "https://thebighead.ca/support")!

    /// Contact Email
    static let contactEmail = "info@thebighead.ca"

    /// App Store URL (placeholder until live)
    static let appStoreURL = URL(string: "https://apps.apple.com/app/gathr/id939330451")!

    /// Whether real Apple Wallet pass generation is enabled.
    /// Requires an Apple Developer signing certificate + server-side .pkpass creation.
    /// When `false`, the app shows a demo wallet-style card with a "Save to Photos" option.
    static let walletPassEnabled = false
}
