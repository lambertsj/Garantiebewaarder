import Foundation
import SwiftData

/// Een bon, foto of ander bestand bij een product.
@Model
final class Attachment {
    var id: UUID = UUID()
    var kindRaw: String = AttachmentKind.receipt.rawValue
    /// Bestandsextensie zonder punt: "jpg", "pdf".
    var fileType: String = "jpg"
    @Attribute(.externalStorage) var data: Data?
    var thumbnailData: Data?
    /// Ruwe OCR-uitvoer, zodat zoeken in bonnen mogelijk is.
    var recognizedText: String = ""
    var createdAt: Date = Date()
    var product: Product?

    init(
        kind: AttachmentKind,
        fileType: String,
        data: Data?,
        thumbnailData: Data? = nil,
        recognizedText: String = "",
        now: Date = Date()
    ) {
        self.kindRaw = kind.rawValue
        self.fileType = fileType
        self.data = data
        self.thumbnailData = thumbnailData
        self.recognizedText = recognizedText
        self.createdAt = now
    }

    var kind: AttachmentKind {
        get { AttachmentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}
