import Foundation
import SwiftData

// MARK: - TriggerEvent

enum TriggerEvent: String, Codable, CaseIterable {
    case onArrival
    case onDeparture
    case both
}

// MARK: - Reminder

@Model
class Reminder {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String

    // Single location
    var latitude: Double
    var longitude: Double
    var radius: Double
    var locationName: String

    // Category mode
    var isCategory: Bool
    var categoryQuery: String
    var searchCenterLat: Double
    var searchCenterLon: Double
    var searchRadiusKm: Double

    // Trigger event (default: onArrival – backwards compatible with existing records)
    var triggerEventRaw: String

    var triggerEvent: TriggerEvent {
        get { TriggerEvent(rawValue: triggerEventRaw) ?? .onArrival }
        set { triggerEventRaw = newValue.rawValue }
    }

    var isDone: Bool
    var createdAt: Date

    init(
        title: String,
        note: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        radius: Double = 100,
        locationName: String = "",
        isCategory: Bool = false,
        categoryQuery: String = "",
        searchCenterLat: Double = 0,
        searchCenterLon: Double = 0,
        searchRadiusKm: Double = 10,
        triggerEvent: TriggerEvent = .onArrival
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.locationName = locationName
        self.isCategory = isCategory
        self.categoryQuery = categoryQuery
        self.searchCenterLat = searchCenterLat
        self.searchCenterLon = searchCenterLon
        self.searchRadiusKm = searchRadiusKm
        self.triggerEventRaw = triggerEvent.rawValue
        self.isDone = false
        self.createdAt = Date()
    }
}
