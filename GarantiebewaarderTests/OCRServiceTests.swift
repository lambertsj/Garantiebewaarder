import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Garantiebewaarder

@Suite("OCRService")
struct OCRServiceTests {
    @Test func blocksOnTheSameHeightAreJoinedLeftToRight() {
        let blocks = [
            OCRService.Block(text: "649,00", box: CGRect(x: 0.7, y: 0.80, width: 0.2, height: 0.03)),
            OCRService.Block(text: "Totaal", box: CGRect(x: 0.1, y: 0.50, width: 0.2, height: 0.03)),
            OCRService.Block(text: "Wasmachine", box: CGRect(x: 0.1, y: 0.801, width: 0.3, height: 0.03)),
            OCRService.Block(text: "649,00", box: CGRect(x: 0.7, y: 0.499, width: 0.2, height: 0.03)),
        ]
        let rows = OCRService.rows(from: blocks)
        #expect(rows == ["Wasmachine  649,00", "Totaal  649,00"])
    }

    @Test func recognizesRenderedReceiptText() throws {
        let size = CGSize(width: 1200, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 64), .foregroundColor: UIColor.black]
            ("Coolblue" as NSString).draw(at: CGPoint(x: 60, y: 60), withAttributes: attributes)
            ("Totaal EUR 49,95" as NSString).draw(at: CGPoint(x: 60, y: 300), withAttributes: attributes)
        }
        let data = try #require(image.jpegData(compressionQuality: 0.95))
        let text = OCRService.recognizeLines(imageData: data).joined(separator: "\n")
        #expect(text.localizedCaseInsensitiveContains("coolblue"))
        #expect(text.contains("49,95"))
    }

    @Test func pdfWithEmbeddedTextSkipsRendering() {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { ctx in
            ctx.beginPage()
            ("Factuur van Coolblue voor een wasmachine, totaal € 649,00" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: nil)
        }
        let lines = OCRService.recognizeLines(pdfData: data)
        #expect(lines.joined().contains("649,00"))
    }

    @Test func garbageDataGivesNoLines() {
        #expect(OCRService.recognizeLines(imageData: Data("geen plaatje".utf8)).isEmpty)
        #expect(OCRService.recognizeLines(pdfData: Data("%PDF-kapot".utf8)).isEmpty)
    }
}
