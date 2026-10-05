import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Garantiebewaarder

@MainActor
@Suite("Persistentie, iCloud en wissen")
struct PersistenceTests {
    @Test func iCloudRequestNeverBlocksTheApp() throws {
        // Op de simulator zonder iCloud-account mag dit nooit crashen of een lege container geven.
        let container = PersistenceController.makeContainer(syncEnabled: true)
        #expect([.iCloud, .iCloudUnavailableUsingLocal].contains(PersistenceController.activeMode))
        let context = ModelContext(container)
        _ = try context.fetchCount(FetchDescriptor<Product>())

        // Terug naar lokaal gebruikt hetzelfde bestand en werkt gewoon.
        let local = PersistenceController.makeContainer(syncEnabled: false)
        #expect(PersistenceController.activeMode == .local)
        _ = try ModelContext(local).fetchCount(FetchDescriptor<Product>())
    }

    @Test func modelMeetsCloudKitRules() {
        // Alle attributen hebben een standaardwaarde of zijn optioneel: een lege init-waarde bestaat.
        let product = Product(name: "x", purchaseDate: Date(), warrantyEndDate: Date())
        #expect(product.attachments == nil)
        let attachment = Garantiebewaarder.Attachment(kind: .other, fileType: "jpg", data: nil)
        #expect(attachment.product == nil)
    }

    @Test func accountStatusMapping() {
        #expect(ICloudStatus.map(.available) == .available)
        #expect(ICloudStatus.map(.noAccount) == .noAccount)
        #expect(ICloudStatus.map(.restricted) == .restricted)
        #expect(ICloudStatus.map(.couldNotDetermine) == .unknown)
        #expect(ICloudStatus.map(.temporarilyUnavailable) == .unknown)
    }

    @Test func deleteEverythingRemovesProductsAttachmentsAndInbox() throws {
        let context = ModelContext(PersistenceController.makeContainer(inMemory: true))
        for i in 0..<5 {
            let p = Product(name: "P\(i)", purchaseDate: Date(), warrantyEndDate: Date())
            context.insert(p)
            let a = Garantiebewaarder.Attachment(kind: .receipt, fileType: "pdf", data: Data([1]))
            a.product = p
            context.insert(a)
        }
        try context.save()
        let inbox = InboxStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("wipe-\(UUID().uuidString)"))
        defer { try? FileManager.default.removeItem(at: inbox.directory) }
        try inbox.add(data: Data([1]), fileExtension: "png")

        try DataEraser.deleteEverything(in: context, inbox: inbox)
        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Garantiebewaarder.Attachment>()) == 0)
        #expect(inbox.pendingFiles().isEmpty)
    }

    @Test func archivedProductsAreExcludedFromListButQueryable() throws {
        let context = ModelContext(PersistenceController.makeContainer(inMemory: true))
        let kept = Product(name: "Actief", purchaseDate: Date(), warrantyEndDate: Date().addingTimeInterval(86_400 * 400))
        let archived = Product(name: "Weg", purchaseDate: Date(), warrantyEndDate: Date().addingTimeInterval(86_400 * 400))
        archived.isArchived = true
        context.insert(kept); context.insert(archived)
        try context.save()
        let onlyArchived = try context.fetch(FetchDescriptor<Product>(predicate: #Predicate { $0.isArchived }))
        #expect(onlyArchived.map(\.name) == ["Weg"])
        #expect(ProductListQuery().apply(to: [kept, archived], leadDays: 30).map(\.name) == ["Actief"])
    }
}
