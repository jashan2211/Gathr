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

    /// App Store URL (placeholder until live)
    static let appStoreURL = URL(string: "https://apps.apple.com/app/gathr/id0000000000")!
}
