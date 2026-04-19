import SwiftUI
import SwiftData
import UserNotifications

@main
struct FutureReminderApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Container selbst erstellen statt .modelContainer(for:) zu nutzen
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
                    LocationManager.shared.modelContainer = container  // ← hier
                }
        }
        .modelContainer(container)  // ← denselben Container übergeben
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
        return true
    }

    // Notification anzeigen wenn App im Vordergrund
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // Tap auf Notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
