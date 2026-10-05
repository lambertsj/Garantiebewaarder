import SwiftUI
import SwiftData

struct ProductListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var products: [Product]
    @AppStorage(AppSettings.Key.reminderLeadDays) private var leadDays = AppSettings.Default.reminderLeadDays

    @State private var query = ProductListQuery()
    @State private var path = NavigationPath()
    @State private var showingAdd = false

    private var visible: [Product] {
        query.apply(to: products, leadDays: leadDays)
    }

    private var hasActiveProducts: Bool { products.contains { !$0.isArchived } }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !hasActiveProducts {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(AppInfo.name)
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Label("action.add", systemImage: "plus") }
                        .accessibilityIdentifier("addButton")
                }
                if hasActiveProducts {
                    ToolbarItem(placement: .topBarLeading) { sortMenu }
                }
            }
            .sheet(isPresented: $showingAdd) {
                ProductEditView(mode: .create) { created in
                    path.append(created)
                }
            }
        }
        .searchable(text: $query.search, prompt: Text("search.prompt"))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("list.empty.title", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("list.empty.message")
        } actions: {
            Button("list.empty.action") { showingAdd = true }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("emptyAddButton")
        }
    }

    private var list: some View {
        List {
            Section {
                filterBar
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if visible.isEmpty {
                ContentUnavailableView.search
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("noResults")
            } else {
                Section {
                    ForEach(visible) { product in
                        NavigationLink(value: product) {
                            ProductRow(product: product, status: product.status(leadDays: leadDays))
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("productList")
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            Picker("filter.status", selection: $query.status) {
                ForEach(ProductStatusFilter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("statusFilter")

            HStack {
                Menu {
                    Picker("filter.category", selection: $query.category) {
                        Text("filter.allCategories").tag(ProductCategory?.none)
                        ForEach(ProductCategory.allCases) { category in
                            Label(String(localized: category.title), systemImage: category.symbolName)
                                .tag(ProductCategory?.some(category))
                        }
                    }
                } label: {
                    Label(
                        query.category.map { String(localized: $0.title) } ?? String(localized: "filter.allCategories"),
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                    .font(.subheadline)
                }
                .accessibilityIdentifier("categoryFilter")
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var sortMenu: some View {
        Menu {
            Picker("sort.title", selection: $query.sort) {
                ForEach(ProductSort.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            Label("sort.title", systemImage: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("sortMenu")
    }
}

#if DEBUG
#Preview("Met producten") {
    ProductListView().modelContainer(PreviewData.container())
}

#Preview("Leeg") {
    ProductListView().modelContainer(PersistenceController.makeContainer(inMemory: true))
}
#endif
