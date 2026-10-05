import Foundation

/// Eén plek voor de naam van de app. De weergavenaam wordt ingesteld in
/// `project.yml` (CFBundleDisplayName).
enum AppInfo {
    /// TODO(user): vul je eigen feedback-adres in (komt in de mailto-link bij "Over deze app").
    static let feedbackEmail = "feedback@example.com"

    static let fallbackName = "Garantiebewaarder"

    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? fallbackName
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
