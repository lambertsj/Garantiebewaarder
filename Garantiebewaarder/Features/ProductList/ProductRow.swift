import SwiftUI

struct ProductRow: View {
    let product: Product
    let status: WarrantyStatus

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(product: product)
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name).font(.headline).lineLimit(2)
                if !product.store.isEmpty {
                    Text(product.store).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 6) {
                    StatusBadge(status: status)
                    Text(product.remaining().text())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("productRow")
    }
}
