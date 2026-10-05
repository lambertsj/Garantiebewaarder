import CoreSpotlight
import SwiftUI

/// Toont de onboarding bij de eerste start en daarna het overzicht.
struct RootView: View {
    @AppStorage(AppSettings.Key.hasCompletedOnboarding) private var hasCompleted = AppSettings.Default.hasCompletedOnboarding

    var body: some View {
        Group {
            if hasCompleted {
                ProductListView()
            } else {
                OnboardingView { hasCompleted = true }
            }
        }
        // Widget (garantiebewaarder://product/<id>) en Spotlight openen het product.
        .onOpenURL { url in
            if let id = SystemIntegration.productID(from: url) { DeepLinkRouter.shared.open(productID: id) }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let id = SystemIntegration.productID(from: activity) { DeepLinkRouter.shared.open(productID: id) }
        }
    }
}
