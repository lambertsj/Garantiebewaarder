import Foundation

/// Wat de planner van een product nodig heeft; los van SwiftData zodat het testbaar blijft.
struct ReminderCandidate: Equatable, Sendable {
    var id: UUID
    var name: String
    var warrantyEndDate: Date
    var isArchived: Bool

    init(id: UUID, name: String, warrantyEndDate: Date, isArchived: Bool) {
        self.id = id
        self.name = name
        self.warrantyEndDate = warrantyEndDate
        self.isArchived = isArchived
    }
}
