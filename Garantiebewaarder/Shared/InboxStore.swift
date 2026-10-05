import Foundation

/// De "inbox" in de App Group: de Share Extension legt hier bestanden neer,
/// de hoofdapp importeert ze. Dit bestand wordt door beide targets gecompileerd
/// en kent het SwiftData-model bewust niet.
struct InboxStore: Sendable {
    static let allowedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "webp", "pdf"]
    static let maxFileBytes = 30_000_000
    static let staleAfter: TimeInterval = 14 * 24 * 3600

    enum InboxError: Error {
        case unsupportedType
        case tooLarge
        case containerUnavailable
    }

    let directory: URL

    /// De inbox in de App Group, of `nil` als die niet beschikbaar is.
    static func shared() -> InboxStore? {
        guard let container = AppGroup.containerURL else { return nil }
        return InboxStore(directory: container.appendingPathComponent("inbox", isDirectory: true))
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Kopieert een bestand de inbox in (voor de extension).
    @discardableResult
    func add(fileAt source: URL, fileExtension: String? = nil) throws -> URL {
        let ext = (fileExtension ?? source.pathExtension).lowercased()
        guard Self.allowedExtensions.contains(ext) else { throw InboxError.unsupportedType }
        let size = (try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.maxFileBytes else { throw InboxError.tooLarge }
        try ensureDirectory()
        let target = directory.appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }

    @discardableResult
    func add(data: Data, fileExtension: String) throws -> URL {
        let ext = fileExtension.lowercased()
        guard Self.allowedExtensions.contains(ext) else { throw InboxError.unsupportedType }
        guard data.count <= Self.maxFileBytes else { throw InboxError.tooLarge }
        try ensureDirectory()
        let target = directory.appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString).\(ext)")
        try data.write(to: target, options: .atomic)
        return target
    }

    /// Wachtende bestanden, oudste eerst.
    func pendingFiles() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { Self.allowedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func remove(_ urls: [URL]) {
        for url in urls { try? FileManager.default.removeItem(at: url) }
    }

    /// Ruimt vergeten bestanden op (bijvoorbeeld als de app lang niet is geopend).
    func purgeStale(now: Date = Date()) {
        for url in pendingFiles() {
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? now
            if now.timeIntervalSince(date) > Self.staleAfter { remove([url]) }
        }
    }
}
