import Foundation
import CoreLocation
import UserNotifications

@MainActor
class LocationManager: NSObject {

    static let shared = LocationManager()

    private let manager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Permissions

    func requestLocationPermission() {
        manager.requestAlwaysAuthorization()
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Geofencing

    func startMonitoring(reminder: Reminder) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("Geofencing not available")
            return
        }
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: reminder.latitude, longitude: reminder.longitude),
            radius: max(reminder.radius, 100),
            identifier: reminder.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        manager.startMonitoring(for: region)
    }

    func stopMonitoring(reminder: Reminder) {
        for region in manager.monitoredRegions {
            if region.identifier == reminder.id.uuidString {
                manager.stopMonitoring(for: region)
            }
        }
    }

    func stopAllMonitoring() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
    }

    func refreshAllGeofences(reminders: [Reminder]) {
        stopAllMonitoring()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for reminder in reminders where !reminder.isDone {
            scheduleNotification(for: reminder)
        }
        print("Refreshed \(reminders.filter { !$0.isDone }.count) geofence(s)")
    }

    // MARK: - Notifications

    func scheduleNotification(for reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.locationName.isEmpty
            ? String(localized: "arrived_at_location")
            : String(format: String(localized: "arrived_at_place"), reminder.locationName)
        content.sound = .default
        content.userInfo = ["reminderID": reminder.id.uuidString]

        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: reminder.latitude, longitude: reminder.longitude),
            radius: max(reminder.radius, 100),
            identifier: reminder.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false

        let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Notification error: \(error)")
            }
        }
    }

    func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminder.id.uuidString]
        )
        stopMonitoring(reminder: reminder)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered region: \(region.identifier)")
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager error: \(error.localizedDescription)")
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     monitoringDidFailFor region: CLRegion?,
                                     withError error: Error) {
        print("Monitoring failed: \(region?.identifier ?? "unknown"), \(error)")
    }
}
