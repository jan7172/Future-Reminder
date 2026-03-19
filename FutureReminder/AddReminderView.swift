import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var locationName = ""
    @State private var radius: Double = 100
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var mapPosition = MapCameraPosition.userLocation(fallback: .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5, longitude: 10.0),
            latitudinalMeters: 100000,
            longitudinalMeters: 100000
        )
    ))

    var canSave: Bool {
        !title.isEmpty && selectedCoordinate != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "reminder_section")) {
                    TextField(String(localized: "title_field"), text: $title)
                    TextField(String(localized: "note_optional"), text: $note)
                }

                Section(String(localized: "location_trigger")) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(String(localized: "search_placeholder"), text: $searchText)
                            .autocorrectionDisabled()
                            .onSubmit { searchLocation() }
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if isSearching {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }

                    if !searchResults.isEmpty {
                        ForEach(0..<searchResults.count, id: \.self) { index in
                            let item = searchResults[index]
                            Button { selectLocation(item) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? String(localized: "unknown"))
                                        .foregroundStyle(.primary)
                                    if let subtitle = item.placemark.title, !subtitle.isEmpty {
                                        Text(subtitle)
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }

                    if let coord = selectedCoordinate {
                        Map(position: $mapPosition) {
                            Marker(
                                locationName.isEmpty ? String(localized: "trigger") : locationName,
                                coordinate: coord
                            )
                            MapCircle(center: coord, radius: radius)
                                .foregroundStyle(.blue.opacity(0.15))
                                .stroke(.blue, lineWidth: 1)
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .disabled(true)

                        HStack {
                            Text(String(format: String(localized: "radius_label"), Int(radius)))
                            Slider(value: $radius, in: 50...500, step: 50)
                        }
                    } else {
                        Map(position: $mapPosition)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .center) {
                                VStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                    Text(String(localized: "search_location_hint"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                    }
                }
            }
            .navigationTitle(String(localized: "new_reminder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "save")) { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        searchResults = []
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            isSearching = false
            if let items = response?.mapItems {
                searchResults = Array(items.prefix(5))
            }
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        let coord = item.location.coordinate
        selectedCoordinate = coord
        locationName = item.name ?? ""
        searchText = locationName
        searchResults = []
        withAnimation {
            mapPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: radius * 5,
                longitudinalMeters: radius * 5
            ))
        }
    }

    private func save() {
        guard let coord = selectedCoordinate else { return }
        let reminder = Reminder(
            title: title,
            note: note,
            latitude: coord.latitude,
            longitude: coord.longitude,
            radius: radius,
            locationName: locationName
        )
        modelContext.insert(reminder)
        LocationManager.shared.scheduleNotification(for: reminder)
        dismiss()
    }
}

