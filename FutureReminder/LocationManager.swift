import Foundation
import CoreLocation
import UserNotifications
import MapKit

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
            if let error { print("Notification permission error: \(error)") }
        }
    }

    // MARK: - Geofencing

    func startMonitoring(reminder: Reminder) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
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
            if region.identifier.hasPrefix(reminder.id.uuidString) {
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
    }

    // MARK: - Schedule (single or category)

    func scheduleNotification(for reminder: Reminder) {
        if reminder.isCategory {
            scheduleCategoryGeofences(for: reminder)
        } else {
            scheduleSingleGeofence(for: reminder)
        }
    }

    // MARK: - Single location

    private func scheduleSingleGeofence(for reminder: Reminder) {
        let content = makeNotificationContent(for: reminder, locationName: reminder.locationName)
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: reminder.latitude, longitude: reminder.longitude),
            radius: max(reminder.radius, 100),
            identifier: reminder.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false

        let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Notification error: \(error)") }
        }
    }

    // MARK: - Category: search + register up to 20 geofences

    func scheduleCategoryGeofences(for reminder: Reminder) {
        let center = CLLocationCoordinate2D(
            latitude: reminder.searchCenterLat,
            longitude: reminder.searchCenterLon
        )
        let radiusMeters = reminder.searchRadiusKm * 1000

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = reminder.categoryQuery
        request.resultTypes = [.pointOfInterest]
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self, let items = response?.mapItems else {
                print("Category search failed: \(error?.localizedDescription ?? "unknown")")
                return
            }

            // Sort by distance from center, take max 20
            let sorted = items
                .sorted {
                    let a = CLLocation(latitude: $0.location.coordinate.latitude, longitude: $0.location.coordinate.longitude)
                    let b = CLLocation(latitude: $1.location.coordinate.latitude, longitude: $1.location.coordinate.longitude)
                    let ref = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    return ref.distance(from: a) < ref.distance(from: b)
                }
                .prefix(20)

            Task { @MainActor in
                for (index, item) in sorted.enumerated() {
                    let coord = item.location.coordinate
                    let placeName = item.name ?? reminder.categoryQuery
                    let identifier = "\(reminder.id.uuidString)_\(index)"

                    let content = self.makeNotificationContent(for: reminder, locationName: placeName)

                    let region = CLCircularRegion(
                        center: coord,
                        radius: max(reminder.radius, 100),
                        identifier: identifier
                    )
                    region.notifyOnEntry = true
                    region.notifyOnExit = false

                    let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                    UNUserNotificationCenter.current().add(request) { error in
                        if let error { print("Category geofence error: \(error)") }
                    }
                }
                print("Registered \(sorted.count) geofence(s) for category: \(reminder.categoryQuery)")
            }
        }
    }

    func cancelNotification(for reminder: Reminder) {
        // Remove all identifiers that start with this reminder's UUID
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(reminder.id.uuidString) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        stopMonitoring(reminder: reminder)
    }

    // MARK: - Helper

    private func makeNotificationContent(for reminder: Reminder, locationName: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = locationName.isEmpty
            ? String(localized: "arrived_at_location")
            : String(format: String(localized: "arrived_at_place"), locationName)
        content.sound = .default
        content.userInfo = ["reminderID": reminder.id.uuidString]
        return content
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.authorizationStatus = manager.authorizationStatus }
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
