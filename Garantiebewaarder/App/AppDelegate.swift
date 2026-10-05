import UIKit
import UserNotifications

/// Zet de notificatie-delegate vroeg genoeg, zodat een tik op een melding
/// ook bij een koude start het juiste product opent.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let idString = response.notification.request.content.userInfo[NotificationScheduler.productIDKey] as? String
        guard let idString, let id = UUID(uuidString: idString) else { return }
        await MainActor.run { DeepLinkRouter.shared.open(productID: id) }
    }
}
