import Foundation

extension ReminderCandidate {
    init(_ product: Product) {
        self.init(id: product.id, name: product.name, warrantyEndDate: product.warrantyEndDate, isArchived: product.isArchived)
    }
}
