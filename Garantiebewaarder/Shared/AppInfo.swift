import Foundation

/// Eén plek voor de naam van de app. De weergavenaam wordt ingesteld in
/// `project.yml` (CFBundleDisplayName).
enum AppInfo {
    /// Feedback en ondersteuning lopen via GitHub (geen e-mailadres, geen account in de app nodig).
    static let feedbackURL = URL(string: "https://github.com/lambertsj/Garantiebewaarder/issues")

    static let fallbackName = "Garantiebewaarder"

    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? fallbackName
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
