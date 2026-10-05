import Foundation

/// Eén plek voor de naam van de app. De weergavenaam wordt ingesteld in
/// `project.yml` (CFBundleDisplayName).
enum AppInfo {
    static let fallbackName = "Garantiebewaarder"

    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? fallbackName
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
