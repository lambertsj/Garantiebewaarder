import SwiftUI

/// Toont de onboarding bij de eerste start en daarna het overzicht.
struct RootView: View {
    @AppStorage(AppSettings.Key.hasCompletedOnboarding) private var hasCompleted = AppSettings.Default.hasCompletedOnboarding

    var body: some View {
        if hasCompleted {
            ProductListView()
        } else {
            OnboardingView { hasCompleted = true }
        }
    }
}
