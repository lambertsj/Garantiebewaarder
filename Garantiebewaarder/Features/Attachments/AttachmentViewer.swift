import SwiftUI
import PDFKit
import UIKit

/// Beeld op volledig scherm: afbeeldingen met zoom, PDF's in PDFKit. Delen via de share sheet.
struct AttachmentViewer: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            content
                .ignoresSafeArea(edges: .bottom)
                .background(Color(.systemBackground))
                .navigationTitle(Text(attachment.kind.title))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("action.close") { dismiss() }.accessibilityIdentifier("closeViewerButton")
                    }
                    if let shareURL {
                        ToolbarItem(placement: .primaryAction) {
                            ShareLink(item: shareURL) { Label("action.share", systemImage: "square.and.arrow.up") }
                        }
                    }
                }
        }
        .task { shareURL = writeTemporaryFile() }
        .onDisappear { if let shareURL { try? FileManager.default.removeItem(at: shareURL) } }
    }

    @ViewBuilder
    private var content: some View {
        if let data = attachment.data {
            if attachment.fileType == "pdf" {
                PDFKitView(data: data)
            } else if let image = UIImage(data: data) {
                ZoomableImageView(image: image)
            } else {
                unavailable
            }
        } else {
            unavailable
        }
    }

    private var unavailable: some View {
        ContentUnavailableView("viewer.unavailable", systemImage: "doc.questionmark")
    }

    private func writeTemporaryFile() -> URL? {
        guard let data = attachment.data else { return nil }
        let name = String(localized: attachment.kind.title)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(attachment.id.uuidString.prefix(6)).\(attachment.fileType)")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

/// UIScrollView-gebaseerde zoom (pinch en dubbeltik).
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 5
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.delegate = context.coordinator
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scroll.frameLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scroll.frameLayoutGuide.bottomAnchor),
        ])
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scroll
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > 1.01 {
                scrollView.setZoomScale(1, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let size = CGSize(width: scrollView.bounds.width / 2.5, height: scrollView.bounds.height / 2.5)
                scrollView.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                           width: size.width, height: size.height), animated: true)
            }
        }
    }
}
