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

    // Trigger event (raw String for SwiftData compatibility)
    var triggerEventRaw: String

    var triggerEvent: TriggerEvent {
        get { TriggerEvent(rawValue: triggerEventRaw) ?? .onArrival }
        set { triggerEventRaw = newValue.rawValue }
    }

    // Time rules – all optional, nil = no restriction
    var activeFrom: Date?    // nicht vor diesem Datum
    var activeUntil: Date?   // nicht nach diesem Datum (inklusive, End of Day)
    var activeOnlyOn: Date?  // nur an diesem Kalendertag

    var isDone: Bool
    var createdAt: Date

    // MARK: - Computed helpers

    var hasTimeRule: Bool {
        activeFrom != nil || activeUntil != nil || activeOnlyOn != nil
    }

    /// True wenn der aktuelle Zeitpunkt alle gesetzten Zeitregeln erfüllt.
    var isActiveNow: Bool {
        let now = Date()
        let calendar = Calendar.current

        // "Nur am" hat Vorrang vor den Bereichsregeln
        if let onlyOn = activeOnlyOn {
            return calendar.isDate(now, inSameDayAs: onlyOn)
        }
        // "Nicht vor"
        if let from = activeFrom, now < calendar.startOfDay(for: from) {
            return false
        }
        // "Nicht nach" – inklusive bis End of Day
        if let until = activeUntil {
            let endOfDay = calendar.date(
                bySettingHour: 23, minute: 59, second: 59, of: until
            ) ?? until
            if now > endOfDay { return false }
        }
        return true
    }

    // MARK: - Init

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
        triggerEvent: TriggerEvent = .onArrival,
        activeFrom: Date? = nil,
        activeUntil: Date? = nil,
        activeOnlyOn: Date? = nil
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
        self.activeFrom = activeFrom
        self.activeUntil = activeUntil
        self.activeOnlyOn = activeOnlyOn
        self.isDone = false
        self.createdAt = Date()
    }
}
