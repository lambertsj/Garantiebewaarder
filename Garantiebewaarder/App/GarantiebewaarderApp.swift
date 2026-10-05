import SwiftUI
import SwiftData

@main
struct GarantiebewaarderApp: App {
    private let container: ModelContainer

    init() {
        // UI-tests starten met een lege opslag in het geheugen.
        let inMemory = ProcessInfo.processInfo.arguments.contains("-UITesting")
        container = PersistenceController.makeContainer(inMemory: inMemory)
    }

    var body: some Scene {
        WindowGroup {
            ProductListView()
        }
        .modelContainer(container)
    }
}
