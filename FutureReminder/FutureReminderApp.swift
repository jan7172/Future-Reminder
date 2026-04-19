import SwiftUI
import SwiftData
import UserNotifications

@main
struct FutureReminderApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let container: ModelContainer = {
        do {
            return try ModelContainer(for: Reminder.self)
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }()

    init() {
        LocationManager.shared.requestLocationPermission()
        LocationManager.shared.requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    LocationManager.shared.modelContainer = container
                }
        }
        .modelContainer(container)
    }
}

// MARK: - Root View

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            ContentView()
        } else {
            OnboardingView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
        return true
    }

    // MARK: - Notification Categories

    private func registerNotificationCategories() {
        let snooze30 = UNNotificationAction(
            identifier: NotificationAction.snooze30,
            title: String(localized: "snooze_30min"),
            options: []
        )
        let snooze60 = UNNotificationAction(
            identifier: NotificationAction.snooze60,
            title: String(localized: "snooze_1h"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: NotificationCategory.reminder,
            actions: [snooze30, snooze60],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Foreground display

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Action handling

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard let reminderID = userInfo["reminderID"] as? String else {
            completionHandler()
            return
        }

        switch response.actionIdentifier {
        case NotificationAction.snooze30:
            LocationManager.shared.snoozeReminder(id: reminderID, interval: 30 * 60)
        case NotificationAction.snooze60:
            LocationManager.shared.snoozeReminder(id: reminderID, interval: 60 * 60)
        default:
            break
        }

        completionHandler()
    }
}

// MARK: - Constants

enum NotificationCategory {
    static let reminder = "REMINDER_CATEGORY"
}

enum NotificationAction {
    static let snooze30 = "SNOOZE_30"
    static let snooze60 = "SNOOZE_60"
}
