import Foundation

/// Voorkeuren, bewaard in UserDefaults (niet in SwiftData). Gebruik de
/// sleutels met `@AppStorage(AppSettings.Key.x)`.
enum AppSettings {
    enum Key {
        static let defaultWarrantyMonths = "defaultWarrantyMonths"
        static let reminderLeadDays = "reminderLeadDays"
        static let remindersEnabled = "remindersEnabled"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    enum Default {
        static let defaultWarrantyMonths = 24
        static let reminderLeadDays = 30
        static let remindersEnabled = true
        static let iCloudSyncEnabled = false
        static let hasCompletedOnboarding = false
    }

    /// Leest een waarde met terugval op de standaard (ook voor niet-view-code).
    static func int(_ key: String, default value: Int, in defaults: UserDefaults = .standard) -> Int {
        defaults.object(forKey: key) == nil ? value : defaults.integer(forKey: key)
    }

    static func bool(_ key: String, default value: Bool, in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) == nil ? value : defaults.bool(forKey: key)
    }
}
