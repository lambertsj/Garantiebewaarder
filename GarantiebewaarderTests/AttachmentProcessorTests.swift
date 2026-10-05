import Foundation
import PDFKit
import Testing
import UIKit
@testable import Garantiebewaarder

@Suite("AttachmentProcessor")
struct AttachmentProcessorTests {
    private func makeImageData(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()!
    }

    private func makePDFData(pages: Int) -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { ctx in
            for page in 0..<pages {
                ctx.beginPage()
                ("Bon \(page)" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: nil)
            }
        }
    }

    @Test func largeImageIsDownscaledToJPEGWithThumbnail() throws {
        let pending = try #require(AttachmentProcessor.processImage(data: makeImageData(width: 4000, height: 3000), kind: .receipt))
        #expect(pending.fileType == "jpg")
        let full = try #require(UIImage(data: pending.data))
        #expect(max(full.size.width * full.scale, full.size.height * full.scale) <= CGFloat(AttachmentProcessor.maxImagePixels))
        let thumb = try #require(pending.thumbnailData.flatMap(UIImage.init(data:)))
        #expect(max(thumb.size.width * thumb.scale, thumb.size.height * thumb.scale) <= CGFloat(AttachmentProcessor.thumbnailPixels))
    }

    @Test func smallImageIsNotUpscaled() throws {
        let pending = try #require(AttachmentProcessor.processImage(data: makeImageData(width: 300, height: 200), kind: .productPhoto))
        let full = try #require(UIImage(data: pending.data))
        #expect(full.size.width * full.scale <= 300)
        #expect(pending.kind == .productPhoto)
    }

    @Test func pdfIsKeptAsIsWithThumbnail() throws {
        let data = makePDFData(pages: 3)
        let pending = try #require(AttachmentProcessor.processPDF(data: data, kind: .receipt))
        #expect(pending.fileType == "pdf")
        #expect(pending.data == data)
        #expect(pending.thumbnailData != nil)
    }

    @Test func processDetectsPDFAndImageByContent() {
        #expect(AttachmentProcessor.process(data: makePDFData(pages: 1), kind: .receipt)?.fileType == "pdf")
        #expect(AttachmentProcessor.process(data: makeImageData(width: 50, height: 50), kind: .receipt)?.fileType == "jpg")
    }

    @Test func garbageIsRejected() {
        let junk = Data("dit is geen afbeelding".utf8)
        #expect(AttachmentProcessor.process(data: junk, kind: .receipt) == nil)
        #expect(AttachmentProcessor.processPDF(data: Data("%PDF-kapot".utf8), kind: .receipt) == nil)
        #expect(AttachmentProcessor.process(data: Data(), kind: .receipt) == nil)
    }

    @Test func oversizedPDFIsRejected() {
        var data = makePDFData(pages: 1)
        data.append(Data(count: AttachmentProcessor.maxPDFBytes))
        #expect(AttachmentProcessor.processPDF(data: data, kind: .receipt) == nil)
    }
}
