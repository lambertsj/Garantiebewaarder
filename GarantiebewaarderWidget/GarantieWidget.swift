import SwiftUI
import WidgetKit

struct GarantieEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct GarantieProvider: TimelineProvider {
    func placeholder(in context: Context) -> GarantieEntry {
        GarantieEntry(date: Date(), snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (GarantieEntry) -> Void) {
        completion(GarantieEntry(date: Date(), snapshot: context.isPreview ? Self.sample : WidgetStore.load()))
    }

    /// Eén entry per dag voor de komende twee weken, zodat "nog N dagen" klopt zonder dat de app draait.
    func getTimeline(in context: Context, completion: @escaping (Timeline<GarantieEntry>) -> Void) {
        let snapshot = WidgetStore.load()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entries = (0..<14).compactMap { offset -> GarantieEntry? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return GarantieEntry(date: offset == 0 ? Date() : day, snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static let sample = WidgetSnapshot(
        items: [
            .init(id: UUID(), name: "Wasmachine", endDate: Calendar.current.date(byAdding: .day, value: 24, to: Date()) ?? Date()),
            .init(id: UUID(), name: "Laptop", endDate: Calendar.current.date(byAdding: .month, value: 5, to: Date()) ?? Date()),
            .init(id: UUID(), name: "E-bike", endDate: Calendar.current.date(byAdding: .month, value: 14, to: Date()) ?? Date()),
        ],
        leadDays: 30, updatedAt: Date()
    )
}

struct GarantieWidgetView: View {
    let entry: GarantieEntry
    @Environment(\.widgetFamily) private var family

    private var visible: [WidgetSnapshot.Item] {
        // Items die sinds het schrijven van de snapshot zijn verlopen, laten we weg.
        let today = Calendar.current.startOfDay(for: entry.date)
        return entry.snapshot.items.filter { $0.endDate >= today }
    }

    var body: some View {
        Group {
            if let first = visible.first {
                if family == .systemSmall {
                    small(first)
                } else {
                    medium(Array(visible.prefix(3)))
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.shield").font(.title)
                    Text("widget.empty").font(.footnote).multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func status(_ item: WidgetSnapshot.Item) -> WarrantyStatus {
        WarrantyCalculator.status(endDate: item.endDate, now: entry.date, leadDays: entry.snapshot.leadDays)
    }

    private func small(_ item: WidgetSnapshot.Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("widget.next").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(item.name).font(.headline).lineLimit(2)
            Label(String(localized: status(item).title), systemImage: status(item).symbolName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color(status(item)))
            Text(WarrantyCalculator.remaining(endDate: item.endDate, now: entry.date).text())
                .font(.subheadline.weight(.medium))
            Text(item.endDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "garantiebewaarder://product/\(item.id.uuidString)"))
    }

    private func medium(_ items: [WidgetSnapshot.Item]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("widget.next").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(items) { item in
                Link(destination: URL(string: "garantiebewaarder://product/\(item.id.uuidString)") ?? URL(fileURLWithPath: "/")) {
                    HStack {
                        Image(systemName: status(item).symbolName).foregroundStyle(color(status(item)))
                        Text(item.name).font(.subheadline.weight(.medium)).lineLimit(1)
                        Spacer()
                        Text(WarrantyCalculator.remaining(endDate: item.endDate, now: entry.date).text())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(_ status: WarrantyStatus) -> Color {
        switch status {
        case .covered: .green
        case .expiringSoon: .orange
        case .expired: .red
        }
    }
}

@main
struct GarantieWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GarantieWidget", provider: GarantieProvider()) { entry in
            GarantieWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.name")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
