import SwiftUI
import UIKit

/// Miniatuur van het eerste bijlage-plaatje, anders het categorie-icoon.
struct ProductThumbnail: View {
    let product: Product
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: product.category.symbolName)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
        .accessibilityHidden(true)
    }

    private var thumbnailImage: UIImage? {
        let attachments = (product.attachments ?? []).sorted { $0.createdAt < $1.createdAt }
        let preferred = attachments.first { $0.kind == .productPhoto && $0.thumbnailData != nil }
            ?? attachments.first { $0.thumbnailData != nil }
        return preferred?.thumbnailData.flatMap(UIImage.init(data:))
    }
}
