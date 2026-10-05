import Foundation
import Observation

/// Bewaart een product dat geopend moet worden (tik op melding, Spotlight, widget).
@MainActor
@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    var pendingProductID: UUID?

    func open(productID: UUID) {
        pendingProductID = productID
    }

    func consume() -> UUID? {
        defer { pendingProductID = nil }
        return pendingProductID
    }
}
