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
                // MARK: - Status
                Section("System Status") {
                    LabeledContent("Notifications", value: notificationStatus)
                    LabeledContent("Location", value: locationStatus)
                    LabeledContent("Monitored Regions", value: "\(monitoredRegionCount())")
                    LabeledContent("Active Reminders", value: "\(reminders.count)")
                }

                // MARK: - Actions
                Section("Trigger Tests") {
                    Button {
                        fireTestNotification()
                    } label: {
                        Label("Fire Test Notification (5s)", systemImage: "bell.fill")
                    }

                    ForEach(reminders) { reminder in
                        Button {
                            fireNotificationFor(reminder)
                        } label: {
                            Label("Trigger: \(reminder.title)", systemImage: "mappin.circle")
                        }
                    }
                }

                // MARK: - Geofence
                Section("Geofence Actions") {
                    Button {
                        reregisterAll()
                    } label: {
                        Label("Re-register all Geofences", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        LocationManager.shared.stopAllMonitoring()
                        addLog("Stopped all monitoring")
                    } label: {
                        Label("Stop all Monitoring", systemImage: "stop.circle")
                    }
                }

                // MARK: - Log
                if !log.isEmpty {
                    Section("Log") {
                        ForEach(log, id: \.self) { entry in
                            Text(entry)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("🛠 Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
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
        content.title = "Future Reminder – Test"
        content.body = "This is a test notification. Everything works! ✅"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error {
                    addLog("❌ Notification error: \(error.localizedDescription)")
                } else {
                    addLog("✅ Test notification scheduled – fires in 5s")
                }
            }
        }
    }

    private func fireNotificationFor(_ reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.locationName.isEmpty
            ? "You've arrived at your reminder location."
            : "You've arrived at \(reminder.locationName)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error {
                    addLog("❌ Error: \(error.localizedDescription)")
                } else {
                    addLog("✅ Triggered: \(reminder.title) – fires in 3s")
                }
            }
        }
    }

    private func reregisterAll() {
        LocationManager.shared.stopAllMonitoring()
        for reminder in reminders {
            LocationManager.shared.scheduleNotification(for: reminder)
        }
        addLog("✅ Re-registered \(reminders.count) geofence(s)")
    }

    private func monitoredRegionCount() -> Int {
        CLLocationManager().monitoredRegions.count
    }

    private func checkStatuses() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized: notificationStatus = "✅ Authorized"
                case .denied: notificationStatus = "❌ Denied"
                case .notDetermined: notificationStatus = "⚠️ Not determined"
                default: notificationStatus = "Unknown"
                }
            }
        }

        let status = CLLocationManager().authorizationStatus
        switch status {
        case .authorizedAlways: locationStatus = "✅ Always"
        case .authorizedWhenInUse: locationStatus = "⚠️ When In Use"
        case .denied: locationStatus = "❌ Denied"
        case .notDetermined: locationStatus = "⚠️ Not determined"
        default: locationStatus = "Unknown"
        }
    }

    private func addLog(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.insert("[\(time)] \(message)", at: 0)
    }
}
