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
        region.notifyOnEntry = reminder.triggerEvent != .onDeparture
        region.notifyOnExit  = reminder.triggerEvent != .onArrival
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
        switch reminder.triggerEvent {
        case .onArrival:
            scheduleRegion(
                for: reminder,
                locationName: reminder.locationName,
                identifier: reminder.id.uuidString,
                isExit: false,
                repeats: false
            )
        case .onDeparture:
            scheduleRegion(
                for: reminder,
                locationName: reminder.locationName,
                identifier: reminder.id.uuidString,
                isExit: true,
                repeats: false
            )
        case .both:
            scheduleRegion(
                for: reminder,
                locationName: reminder.locationName,
                identifier: "\(reminder.id.uuidString)_entry",
                isExit: false,
                repeats: false
            )
            scheduleRegion(
                for: reminder,
                locationName: reminder.locationName,
                identifier: "\(reminder.id.uuidString)_exit",
                isExit: true,
                repeats: false
            )
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

                    switch reminder.triggerEvent {
                    case .onArrival:
                        self.scheduleRegion(
                            for: reminder,
                            coord: coord,
                            locationName: placeName,
                            identifier: "\(reminder.id.uuidString)_\(index)",
                            isExit: false,
                            repeats: true
                        )
                    case .onDeparture:
                        self.scheduleRegion(
                            for: reminder,
                            coord: coord,
                            locationName: placeName,
                            identifier: "\(reminder.id.uuidString)_\(index)",
                            isExit: true,
                            repeats: true
                        )
                    case .both:
                        self.scheduleRegion(
                            for: reminder,
                            coord: coord,
                            locationName: placeName,
                            identifier: "\(reminder.id.uuidString)_\(index)_entry",
                            isExit: false,
                            repeats: true
                        )
                        self.scheduleRegion(
                            for: reminder,
                            coord: coord,
                            locationName: placeName,
                            identifier: "\(reminder.id.uuidString)_\(index)_exit",
                            isExit: true,
                            repeats: true
                        )
                    }
                }
                print("Registered \(sorted.count) geofence(s) for category: \(reminder.categoryQuery)")
            }
        }
    }

    // MARK: - Region scheduling helper

    /// Schedules a single UNLocationNotificationRequest for either entry or exit.
    private func scheduleRegion(
        for reminder: Reminder,
        coord: CLLocationCoordinate2D? = nil,
        locationName: String,
        identifier: String,
        isExit: Bool,
        repeats: Bool
    ) {
        let center = coord ?? CLLocationCoordinate2D(
            latitude: reminder.latitude,
            longitude: reminder.longitude
        )
        let content = makeNotificationContent(for: reminder, locationName: locationName, isExit: isExit)
        let region = CLCircularRegion(
            center: center,
            radius: max(reminder.radius, 100),
            identifier: identifier
        )
        region.notifyOnEntry = !isExit
        region.notifyOnExit  = isExit

        let trigger = UNLocationNotificationTrigger(region: region, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Notification error [\(identifier)]: \(error)") }
        }
    }

    func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(reminder.id.uuidString) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        stopMonitoring(reminder: reminder)
    }

    // MARK: - Notification content

    private func makeNotificationContent(
        for reminder: Reminder,
        locationName: String,
        isExit: Bool
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        if isExit {
            content.body = locationName.isEmpty
                ? String(localized: "left_location")
                : String(format: String(localized: "left_place"), locationName)
        } else {
            content.body = locationName.isEmpty
                ? String(localized: "arrived_at_location")
                : String(format: String(localized: "arrived_at_place"), locationName)
        }
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

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Exited region: \(region.identifier)")
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
