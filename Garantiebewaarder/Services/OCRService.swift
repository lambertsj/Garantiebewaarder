import Foundation
import PDFKit
import UIKit
import Vision

/// Tekstherkenning met Apple Vision, volledig op het toestel.
enum OCRService {
    /// Eén herkend tekstblok met positie (genormaliseerd, oorsprong linksonder).
    struct Block: Equatable, Sendable {
        var text: String
        var box: CGRect
    }

    static let maxPDFPagesToRender = 3

    // MARK: Publiek

    /// Herkent de regels tekst in een bijlage. Geeft een lege lijst als er niets
    /// te herkennen valt of herkenning mislukt; de gebruiker vult dan zelf in.
    static func recognizeLines(in attachment: PendingAttachment) -> [String] {
        attachment.fileType == "pdf" ? recognizeLines(pdfData: attachment.data) : recognizeLines(imageData: attachment.data)
    }

    static func recognizeLines(imageData: Data) -> [String] {
        guard let cgImage = AttachmentProcessor.downsample(data: imageData, maxPixels: AttachmentProcessor.maxImagePixels) else { return [] }
        return rows(from: recognizeBlocks(in: cgImage))
    }

    /// PDF's met ingebedde tekst gebruiken die tekst direct; gescande PDF's worden
    /// per pagina als afbeelding herkend.
    static func recognizeLines(pdfData: Data) -> [String] {
        guard let document = PDFDocument(data: pdfData) else { return [] }
        let embedded = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if embedded.joined().count > 40 { return embedded }

        var lines: [String] = []
        for index in 0..<min(document.pageCount, maxPDFPagesToRender) {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale = 2000 / max(bounds.width, bounds.height)
            let image = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
            if let cgImage = image.cgImage { lines += rows(from: recognizeBlocks(in: cgImage)) }
        }
        return lines
    }

    // MARK: Vision

    static func recognizeBlocks(in image: CGImage) -> [Block] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["nl-NL", "en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return Block(text: candidate.string, box: observation.boundingBox)
        }
    }

    /// Voegt blokken die op dezelfde hoogte staan samen tot één regel
    /// ("Wasmachine   649,00"), van boven naar beneden en van links naar rechts.
    static func rows(from blocks: [Block]) -> [String] {
        let sorted = blocks.sorted { $0.box.midY > $1.box.midY }
        var rows: [[Block]] = []
        for block in sorted {
            if let last = rows.last, let reference = last.first,
               abs(block.box.midY - reference.box.midY) <= min(block.box.height, reference.box.height) * 0.6 {
                rows[rows.count - 1].append(block)
            } else {
                rows.append([block])
            }
        }
        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "  ")
        }
    }
}
