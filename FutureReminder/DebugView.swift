import SwiftUI
import SwiftData
import CoreLocation
import UserNotifications

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var reminders: [Reminder]

    @State private var log: [String] = []
    @State private var notificationStatus = "Unknown"
    @State private var locationStatus = "Unknown"

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "System Status")) {
                    LabeledContent(String(localized: "Notifications"), value: notificationStatus)
                    LabeledContent(String(localized: "Location"), value: locationStatus)
                    LabeledContent(String(localized: "Monitored Regions"), value: "\(monitoredRegionCount())")
                    LabeledContent(String(localized: "Active Reminders"), value: "\(reminders.count)")
                }

                Section(String(localized: "Trigger Tests")) {
                    Button {
                        fireTestNotification()
                    } label: {
                        Label(String(localized: "Fire Test Notification (5s)"), systemImage: "bell.fill")
                    }

                    ForEach(reminders) { reminder in
                        Button {
                            fireNotificationFor(reminder)
                        } label: {
                            Label(String(format: String(localized: "Trigger: %@"), reminder.title), systemImage: "mappin.circle")
                        }
                    }
                }

                Section(String(localized: "Geofence Actions")) {
                    Button {
                        reregisterAll()
                    } label: {
                        Label(String(localized: "Re-register all Geofences"), systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        LocationManager.shared.stopAllMonitoring()
                        addLog("✅ \(String(localized: "Stop all Monitoring"))")
                    } label: {
                        Label(String(localized: "Stop all Monitoring"), systemImage: "stop.circle")
                    }
                }

                if !log.isEmpty {
                    Section(String(localized: "Log")) {
                        ForEach(log, id: \.self) { entry in
                            Text(entry)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "🛠 Debug Menu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
            .onAppear {
                checkStatuses()
            }
        }
    }

    // MARK: - Functions

    private func fireTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "future_reminder")
        content.body = String(localized: "debug_test_notification_body")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error {
                    addLog("❌ \(error.localizedDescription)")
                } else {
                    addLog("✅ \(String(localized: "debug_log_test_scheduled"))")
                }
            }
        }
    }

    private func fireNotificationFor(_ reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.locationName.isEmpty
            ? String(localized: "arrived_at_location")
            : String(format: String(localized: "arrived_at_place"), reminder.locationName)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error {
                    addLog("❌ \(error.localizedDescription)")
                } else {
                    addLog("✅ \(String(format: String(localized: "debug_log_triggered"), reminder.title))")
                }
            }
        }
    }

    private func reregisterAll() {
        LocationManager.shared.stopAllMonitoring()
        for reminder in reminders {
            LocationManager.shared.scheduleNotification(for: reminder)
        }
        addLog("✅ \(String(format: String(localized: "debug_log_reregistered"), reminders.count))")
    }

    private func monitoredRegionCount() -> Int {
        CLLocationManager().monitoredRegions.count
    }

    private func checkStatuses() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized: notificationStatus = "✅ \(String(localized: "debug_status_authorized"))"
                case .denied: notificationStatus = "❌ \(String(localized: "debug_status_denied"))"
                case .notDetermined: notificationStatus = "⚠️ \(String(localized: "debug_status_not_determined"))"
                default: notificationStatus = String(localized: "unknown")
                }
            }
        }

        let status = CLLocationManager().authorizationStatus
        switch status {
        case .authorizedAlways: locationStatus = "✅ \(String(localized: "debug_location_always"))"
        case .authorizedWhenInUse: locationStatus = "⚠️ \(String(localized: "debug_location_when_in_use"))"
        case .denied: locationStatus = "❌ \(String(localized: "debug_status_denied"))"
        case .notDetermined: locationStatus = "⚠️ \(String(localized: "debug_status_not_determined"))"
        default: locationStatus = String(localized: "unknown")
        }
    }

    private func addLog(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.insert("[\(time)] \(message)", at: 0)
    }
}
