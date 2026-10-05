import Foundation
import ImageIO
import PDFKit
import UIKit
import UniformTypeIdentifiers

/// Een bijlage die nog niet in SwiftData is bewaard (tijdens het bewerken).
struct PendingAttachment: Identifiable, Hashable, Sendable {
    let id = UUID()
    var kind: AttachmentKind
    var fileType: String
    var data: Data
    var thumbnailData: Data?
    var recognizedText = ""

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Verkleint afbeeldingen, maakt miniaturen en valideert PDF's. Alles is
/// synchroon en thread-veilig; roep het aan vanuit een achtergrondtaak.
enum AttachmentProcessor {
    static let maxImagePixels = 2400
    static let thumbnailPixels = 240
    static let jpegQuality: CGFloat = 0.8
    static let maxPDFBytes = 30_000_000

    /// Verkleint (indien nodig), corrigeert de oriëntatie en codeert als JPEG.
    static func processImage(data: Data, kind: AttachmentKind) -> PendingAttachment? {
        guard let full = downsample(data: data, maxPixels: maxImagePixels),
              let jpeg = jpegData(from: full),
              let thumb = downsample(data: data, maxPixels: thumbnailPixels),
              let thumbData = jpegData(from: thumb, quality: 0.7)
        else { return nil }
        return PendingAttachment(kind: kind, fileType: "jpg", data: jpeg, thumbnailData: thumbData)
    }

    static func processImage(_ image: UIImage, kind: AttachmentKind) -> PendingAttachment? {
        guard let data = image.jpegData(compressionQuality: 0.95) else { return nil }
        return processImage(data: data, kind: kind)
    }

    /// Geeft `nil` als het geen leesbare PDF is of hij te groot is.
    static func processPDF(data: Data, kind: AttachmentKind) -> PendingAttachment? {
        guard data.count <= maxPDFBytes,
              let document = PDFDocument(data: data), document.pageCount > 0,
              let page = document.page(at: 0)
        else { return nil }
        let thumb = page.thumbnail(of: CGSize(width: thumbnailPixels, height: thumbnailPixels), for: .mediaBox)
        return PendingAttachment(kind: kind, fileType: "pdf", data: data, thumbnailData: thumb.jpegData(compressionQuality: 0.7))
    }

    /// Kiest op basis van de inhoud: PDF of afbeelding.
    static func process(data: Data, kind: AttachmentKind) -> PendingAttachment? {
        if data.starts(with: Data("%PDF".utf8)) { return processPDF(data: data, kind: kind) }
        return processImage(data: data, kind: kind)
    }

    static func downsample(data: Data, maxPixels: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func jpegData(from image: CGImage, quality: CGFloat = jpegQuality) -> Data? {
        UIImage(cgImage: image).jpegData(compressionQuality: quality)
    }
}
