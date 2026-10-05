import SwiftUI
import SwiftData

@main
struct GarantiebewaarderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer

    init() {
        // UI-tests starten met een lege opslag in het geheugen.
        let arguments = ProcessInfo.processInfo.arguments
        let inMemory = arguments.contains("-UITesting")
        if inMemory {
            // Deterministische start: onboarding alleen als de test erom vraagt.
            UserDefaults.standard.set(!arguments.contains("-UITestingOnboarding"), forKey: AppSettings.Key.hasCompletedOnboarding)
        }
        container = PersistenceController.makeContainer(inMemory: inMemory)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
