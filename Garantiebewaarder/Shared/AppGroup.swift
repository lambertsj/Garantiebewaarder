import Foundation

/// Gedeelde container tussen app, Share Extension en widget.
/// TODO(user): de App Group-id moet overeenkomen met je Apple Developer-account (Certificates, Identifiers & Profiles).
enum AppGroup {
    static let identifier = "group.com.jeroenlamberts.garantiebewaarder"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
