import Foundation
import CoreLocation
import UserNotifications
import MapKit
import SwiftData

@MainActor
class LocationManager: NSObject {

    static let shared = LocationManager()

    private let manager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Set this from your @main App struct so the delegate can fetch Reminders.
    /// Example: LocationManager.shared.modelContainer = container
    var modelContainer: ModelContainer?

    /// In-memory cache: identifier → locationName for time-rule geofences.
    /// Populated at scheduling time; used in the delegate to build notification content.
    private var regionLocationNames: [String: String] = [:]

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

    // MARK: - Stop / refresh

    func stopMonitoring(reminder: Reminder) {
        for region in manager.monitoredRegions where region.identifier.hasPrefix(reminder.id.uuidString) {
            manager.stopMonitoring(for: region)
        }
    }

    func stopAllMonitoring() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        regionLocationNames.removeAll()
    }

    func refreshAllGeofences(reminders: [Reminder]) {
        stopAllMonitoring()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for reminder in reminders where !reminder.isDone {
            scheduleNotification(for: reminder)
        }
    }

    func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }.filter { $0.hasPrefix(reminder.id.uuidString) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        stopMonitoring(reminder: reminder)
        // Clean up cache
        regionLocationNames = regionLocationNames.filter { !$0.key.hasPrefix(reminder.id.uuidString) }
    }

    // MARK: - Schedule entry point

    func scheduleNotification(for reminder: Reminder) {
        if reminder.hasTimeRule {
            // Time-rule reminders use CLLocationManager monitoring + delegate-fired notifications
            if reminder.isCategory {
                scheduleCategoryWithTimeRule(for: reminder)
            } else {
                scheduleSingleWithTimeRule(for: reminder)
            }
        } else {
            // No time rule: use UNLocationNotificationTrigger (simpler, more reliable)
            if reminder.isCategory {
                scheduleCategoryGeofences(for: reminder)
            } else {
                scheduleSingleGeofence(for: reminder)
            }
        }
    }

    // MARK: - Single location (no time rule)

    private func scheduleSingleGeofence(for reminder: Reminder) {
        switch reminder.triggerEvent {
        case .onArrival:
            scheduleUNRegion(for: reminder, locationName: reminder.locationName,
                             identifier: reminder.id.uuidString, isExit: false, repeats: false)
        case .onDeparture:
            scheduleUNRegion(for: reminder, locationName: reminder.locationName,
                             identifier: reminder.id.uuidString, isExit: true, repeats: false)
        case .both:
            scheduleUNRegion(for: reminder, locationName: reminder.locationName,
                             identifier: "\(reminder.id.uuidString)_entry", isExit: false, repeats: false)
            scheduleUNRegion(for: reminder, locationName: reminder.locationName,
                             identifier: "\(reminder.id.uuidString)_exit", isExit: true, repeats: false)
        }
    }

    /// Schedules a UNLocationNotificationTrigger-based request (no time rule).
    private func scheduleUNRegion(
        for reminder: Reminder,
        coord: CLLocationCoordinate2D? = nil,
        locationName: String,
        identifier: String,
        isExit: Bool,
        repeats: Bool
    ) {
        let center = coord ?? CLLocationCoordinate2D(latitude: reminder.latitude, longitude: reminder.longitude)
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
            if let error { print("UNNotification error [\(identifier)]: \(error)") }
        }
    }

    // MARK: - Category (no time rule)

    func scheduleCategoryGeofences(for reminder: Reminder) {
        let center = CLLocationCoordinate2D(latitude: reminder.searchCenterLat, longitude: reminder.searchCenterLon)
        let radiusMeters = reminder.searchRadiusKm * 1000
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = reminder.categoryQuery
        request.resultTypes = [.pointOfInterest]
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )
        MKLocalSearch(request: request).start { [weak self] response, error in
            guard let self, let items = response?.mapItems else {
                print("Category search failed: \(error?.localizedDescription ?? "unknown")")
                return
            }
            let sorted = items.sorted {
                let ref = CLLocation(latitude: center.latitude, longitude: center.longitude)
                let a = CLLocation(latitude: $0.location.coordinate.latitude, longitude: $0.location.coordinate.longitude)
                let b = CLLocation(latitude: $1.location.coordinate.latitude, longitude: $1.location.coordinate.longitude)
                return ref.distance(from: a) < ref.distance(from: b)
            }.prefix(20)

            Task { @MainActor in
                for (index, item) in sorted.enumerated() {
                    let coord = item.location.coordinate
                    let placeName = item.name ?? reminder.categoryQuery
                    switch reminder.triggerEvent {
                    case .onArrival:
                        self.scheduleUNRegion(for: reminder, coord: coord, locationName: placeName,
                                              identifier: "\(reminder.id.uuidString)_\(index)",
                                              isExit: false, repeats: true)
                    case .onDeparture:
                        self.scheduleUNRegion(for: reminder, coord: coord, locationName: placeName,
                                              identifier: "\(reminder.id.uuidString)_\(index)",
                                              isExit: true, repeats: true)
                    case .both:
                        self.scheduleUNRegion(for: reminder, coord: coord, locationName: placeName,
                                              identifier: "\(reminder.id.uuidString)_\(index)_entry",
                                              isExit: false, repeats: true)
                        self.scheduleUNRegion(for: reminder, coord: coord, locationName: placeName,
                                              identifier: "\(reminder.id.uuidString)_\(index)_exit",
                                              isExit: true, repeats: true)
                    }
                }
                print("Registered \(sorted.count) geofence(s) for category: \(reminder.categoryQuery)")
            }
        }
    }

    // MARK: - Single location (with time rule)

    private func scheduleSingleWithTimeRule(for reminder: Reminder) {
        switch reminder.triggerEvent {
        case .onArrival:
            registerCLRegion(identifier: reminder.id.uuidString,
                             lat: reminder.latitude, lon: reminder.longitude, radius: reminder.radius,
                             notifyEntry: true, notifyExit: false,
                             locationName: reminder.locationName)
        case .onDeparture:
            registerCLRegion(identifier: reminder.id.uuidString,
                             lat: reminder.latitude, lon: reminder.longitude, radius: reminder.radius,
                             notifyEntry: false, notifyExit: true,
                             locationName: reminder.locationName)
        case .both:
            registerCLRegion(identifier: "\(reminder.id.uuidString)_entry",
                             lat: reminder.latitude, lon: reminder.longitude, radius: reminder.radius,
                             notifyEntry: true, notifyExit: false,
                             locationName: reminder.locationName)
            registerCLRegion(identifier: "\(reminder.id.uuidString)_exit",
                             lat: reminder.latitude, lon: reminder.longitude, radius: reminder.radius,
                             notifyEntry: false, notifyExit: true,
                             locationName: reminder.locationName)
        }
    }

    // MARK: - Category (with time rule)

    private func scheduleCategoryWithTimeRule(for reminder: Reminder) {
        let centerLat = reminder.searchCenterLat
        let centerLon = reminder.searchCenterLon
        let radiusKm  = reminder.searchRadiusKm
        let query     = reminder.categoryQuery
        let reminderRadius = reminder.radius
        let reminderID = reminder.id
        let triggerEvent = reminder.triggerEvent

        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest]
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusKm * 1000 * 2,
            longitudinalMeters: radiusKm * 1000 * 2
        )
        MKLocalSearch(request: request).start { [weak self] response, error in
            guard let self, let items = response?.mapItems else {
                print("Category (time-rule) search failed: \(error?.localizedDescription ?? "unknown")")
                return
            }
            let sorted = items.sorted {
                let ref = CLLocation(latitude: center.latitude, longitude: center.longitude)
                let a = CLLocation(latitude: $0.location.coordinate.latitude, longitude: $0.location.coordinate.longitude)
                let b = CLLocation(latitude: $1.location.coordinate.latitude, longitude: $1.location.coordinate.longitude)
                return ref.distance(from: a) < ref.distance(from: b)
            }.prefix(20)

            Task { @MainActor in
                for (index, item) in sorted.enumerated() {
                    let coord = item.location.coordinate
                    let placeName = item.name ?? query
                    switch triggerEvent {
                    case .onArrival:
                        self.registerCLRegion(
                            identifier: "\(reminderID.uuidString)_\(index)",
                            lat: coord.latitude, lon: coord.longitude, radius: reminderRadius,
                            notifyEntry: true, notifyExit: false, locationName: placeName)
                    case .onDeparture:
                        self.registerCLRegion(
                            identifier: "\(reminderID.uuidString)_\(index)",
                            lat: coord.latitude, lon: coord.longitude, radius: reminderRadius,
                            notifyEntry: false, notifyExit: true, locationName: placeName)
                    case .both:
                        self.registerCLRegion(
                            identifier: "\(reminderID.uuidString)_\(index)_entry",
                            lat: coord.latitude, lon: coord.longitude, radius: reminderRadius,
                            notifyEntry: true, notifyExit: false, locationName: placeName)
                        self.registerCLRegion(
                            identifier: "\(reminderID.uuidString)_\(index)_exit",
                            lat: coord.latitude, lon: coord.longitude, radius: reminderRadius,
                            notifyEntry: false, notifyExit: true, locationName: placeName)
                    }
                }
                print("Registered \(sorted.count) time-rule geofence(s) for category: \(query)")
            }
        }
    }

    // MARK: - CLLocationManager region helper

    private func registerCLRegion(
        identifier: String,
        lat: Double, lon: Double,
        radius: Double,
        notifyEntry: Bool,
        notifyExit: Bool,
        locationName: String
    ) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            radius: max(radius, 100),
            identifier: identifier
        )
        region.notifyOnEntry = notifyEntry
        region.notifyOnExit  = notifyExit
        regionLocationNames[identifier] = locationName
        manager.startMonitoring(for: region)
    }

    // MARK: - Time-rule delegate handler

    /// Called from didEnterRegion / didExitRegion.
    /// Looks up the matching Reminder, checks time rules, fires notification if valid.
    private func handleRegionTransition(identifier: String, isExit: Bool) {
        guard let container = modelContainer else {
            print("LocationManager: modelContainer not set – cannot handle time-rule transition")
            return
        }
        let context = ModelContext(container)
        guard let allReminders = try? context.fetch(FetchDescriptor<Reminder>()) else { return }

        guard let reminder = allReminders.first(where: {
            identifier.hasPrefix($0.id.uuidString) && $0.hasTimeRule && !$0.isDone
        }) else { return }

        guard reminder.isActiveNow else {
            print("Time rule not met for '\(reminder.title)' at \(Date())")
            return
        }

        let locationName = regionLocationNames[identifier] ?? reminder.locationName
        let content = makeNotificationContent(for: reminder, locationName: locationName, isExit: isExit)
        // Unique identifier so multiple firings don't overwrite each other
        let notifID = "tr_\(identifier)_\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: notifID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Time-rule notification error: \(error)") }
        }
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
        Task { @MainActor in self.handleRegionTransition(identifier: region.identifier, isExit: false) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Exited region: \(region.identifier)")
        Task { @MainActor in self.handleRegionTransition(identifier: region.identifier, isExit: true) }
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
