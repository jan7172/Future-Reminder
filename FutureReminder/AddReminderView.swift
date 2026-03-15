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
                Section("Reminder") {
                    TextField("Title", text: $title)
                    TextField("Note (optional)", text: $note)
                }

                Section("Location Trigger") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search address or place...", text: $searchText)
                            .autocorrectionDisabled()
                            .onSubmit {
                                searchLocation()
                            }
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
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }

                    if !searchResults.isEmpty {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                selectLocation(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unknown")
                                        .foregroundStyle(.primary)
                                        .font(.body)
                                    if let address = item.placemark.title {
                                        Text(address)
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }

                    if let coord = selectedCoordinate {
                        Map(position: $mapPosition) {
                            Marker(locationName.isEmpty ? "Trigger" : locationName,
                                   coordinate: coord)
                            MapCircle(center: coord, radius: radius)
                                .foregroundStyle(.blue.opacity(0.15))
                                .stroke(.blue, lineWidth: 1)
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .disabled(true)

                        HStack {
                            Text("Radius: \(Int(radius)) m")
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
                                    Text("Search for a location above")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                    }
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Search

    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        searchResults = []

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.address, .pointOfInterest]

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            if let items = response?.mapItems {
                searchResults = Array(items.prefix(5))
            }
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        selectedCoordinate = coord
        locationName = item.name ?? item.placemark.title ?? ""
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

    // MARK: - Save

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
