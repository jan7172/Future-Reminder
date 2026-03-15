import Foundation
import SwiftData

@Model
class Reminder {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var latitude: Double
    var longitude: Double
    var radius: Double
    var locationName: String
    var isDone: Bool
    var createdAt: Date

    init(
        title: String,
        note: String = "",
        latitude: Double,
        longitude: Double,
        radius: Double = 100,
        locationName: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.locationName = locationName
        self.isDone = false
        self.createdAt = Date()
    }
}
