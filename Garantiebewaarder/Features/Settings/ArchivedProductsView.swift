import SwiftUI
import SwiftData

/// Producten die je hebt weggedaan of verkocht. Ze krijgen geen herinneringen meer.
struct ArchivedProductsView: View {
    @Query(filter: #Predicate<Product> { $0.isArchived }, sort: \Product.updatedAt, order: .reverse)
    private var archived: [Product]

    var body: some View {
        Group {
            if archived.isEmpty {
                ContentUnavailableView("archived.empty.title", systemImage: "archivebox",
                                       description: Text("archived.empty.message"))
            } else {
                List(archived) { product in
                    NavigationLink {
                        ProductDetailView(product: product)
                    } label: {
                        HStack(spacing: 12) {
                            ProductThumbnail(product: product)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name).font(.headline)
                                Text(product.warrantyEndDate.formatted(date: .long, time: .omitted))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("archivedRow")
                }
            }
        }
        .navigationTitle("archived.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
