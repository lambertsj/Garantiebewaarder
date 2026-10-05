import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Share Extension: legt gedeelde afbeeldingen en PDF's in de inbox van de
/// App Group. De hoofdapp maakt het af. Geen netwerk, geen model.
final class ShareViewController: UIViewController {
    private let model = ShareStatusModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareStatusView(model: model) { [weak self] in self?.finish() })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Task { await importAttachments() }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func importAttachments() async {
        guard let inbox = InboxStore.shared() else {
            model.state = .failed(.unavailable)
            return
        }
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        var saved = 0
        var failure: ShareStatusModel.Failure?
        for provider in providers {
            guard let type = [UTType.pdf, UTType.image].first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) else { continue }
            switch await Self.copy(provider, type: type, into: inbox) {
            case .success: saved += 1
            case .failure(let error):
                failure = (error as? InboxStore.InboxError) == .tooLarge ? .tooLarge : .unreadable
            }
        }
        if saved > 0 {
            model.state = .saved(count: saved)
        } else {
            model.state = .failed(failure ?? .unsupported)
        }
    }

    /// De tijdelijke bestands-URL is alleen geldig binnen de completion; kopieer dus direct.
    private static func copy(_ provider: NSItemProvider, type: UTType, into inbox: InboxStore) async -> Result<Void, Error> {
        await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                guard let url else {
                    continuation.resume(returning: .failure(error ?? InboxStore.InboxError.unsupportedType))
                    return
                }
                do {
                    let ext = url.pathExtension.isEmpty ? (type.preferredFilenameExtension ?? "") : url.pathExtension
                    try inbox.add(fileAt: url, fileExtension: ext)
                    continuation.resume(returning: .success(()))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }
}

extension InboxStore.InboxError: Equatable {}

@MainActor
@Observable
final class ShareStatusModel {
    enum Failure { case unavailable, unsupported, unreadable, tooLarge }
    enum State { case working, saved(count: Int), failed(Failure) }
    var state: State = .working
}

struct ShareStatusView: View {
    let model: ShareStatusModel
    let done: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch model.state {
            case .working:
                ProgressView()
                Text("share.working")
            case .saved:
                Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(.green)
                Text("share.saved").font(.headline)
                Text("share.openApp").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            case .failed(let failure):
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 48)).foregroundStyle(.orange)
                Text(failure.message).font(.headline).multilineTextAlignment(.center)
            }
            Button("share.done", action: done)
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private extension ShareStatusModel.Failure {
    var message: LocalizedStringKey {
        switch self {
        case .unavailable: "share.error.unavailable"
        case .unsupported: "share.error.unsupported"
        case .unreadable: "share.error.unreadable"
        case .tooLarge: "share.error.tooLarge"
        }
    }
}
