import SwiftUI
import UIKit

/// Horizontale rij miniaturen in het productdetail; tik opent de viewer.
struct AttachmentGrid: View {
    let attachments: [Attachment]
    @State private var selected: Attachment?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(attachments) { attachment in
                    Button { selected = attachment } label: {
                        VStack(spacing: 4) {
                            AttachmentThumbnail(thumbnailData: attachment.thumbnailData, isPDF: attachment.fileType == "pdf", size: 88)
                            Text(attachment.kind.title).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(attachment.kind.title))
                    .accessibilityHint(Text("attachment.openHint"))
                    .accessibilityIdentifier("attachmentThumb")
                }
            }
            .padding(.vertical, 4)
        }
        .fullScreenCover(item: $selected) { AttachmentViewer(attachment: $0) }
    }
}

struct AttachmentThumbnail: View {
    let thumbnailData: Data?
    let isPDF: Bool
    var size: CGFloat = 64

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = thumbnailData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: isPDF ? "doc.richtext" : "photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
            if isPDF {
                Text("PDF").font(.caption2.bold()).padding(3)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4)).padding(3)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
