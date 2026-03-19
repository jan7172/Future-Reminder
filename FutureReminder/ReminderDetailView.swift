import SwiftUI
import MapKit
import CoreLocation
import SwiftData

struct ReminderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var reminder: Reminder

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editNote = ""
    @State private var editLocationName = ""
    @State private var editRadius: Double = 100
    @State private var editCoordinate: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5, longitude: 10.0),
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
    )

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: reminder.latitude, longitude: reminder.longitude)
    }

    var body: some View {
        Form {
            if isEditing {
                editView
            } else {
                detailView
            }
        }
        .navigationTitle(isEditing ? String(localized: "edit_reminder") : reminder.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button(String(localized: "save")) { saveEdits() }
                        .fontWeight(.semibold)
                } else {
                    Button(String(localized: "edit")) { startEditing() }
                }
            }
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "cancel")) { isEditing = false }
                }
            }
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    var detailView: some View {
        Section(String(localized: "reminder_section")) {
            LabeledContent(String(localized: "title_field"), value: reminder.title)
            if !reminder.note.isEmpty {
                LabeledContent(String(localized: "note_optional"), value: reminder.note)
            }
            LabeledContent(
                String(localized: "status"),
                value: reminder.isDone
                    ? String(localized: "status_done")
                    : String(localized: "status_open")
            )
        }

        Section(String(localized: "location_trigger")) {
            if !reminder.locationName.isEmpty {
                Label(reminder.locationName, systemImage: "mappin.circle")
            }
            LabeledContent("Radius", value: "\(Int(reminder.radius)) m")

            Map {
                Marker(
                    reminder.locationName.isEmpty ? String(localized: "trigger") : reminder.locationName,
                    coordinate: coordinate
                )
                MapCircle(center: coordinate, radius: reminder.radius)
                    .foregroundStyle(.blue.opacity(0.15))
                    .stroke(.blue, lineWidth: 1)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(true)
        }

        Section {
            if !reminder.isDone {
                Button {
                    reminder.isDone = true
                    LocationManager.shared.cancelNotification(for: reminder)
                    dismiss()
                } label: {
                    Label(String(localized: "mark_as_done"), systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
            Button(role: .destructive) {
                LocationManager.shared.cancelNotification(for: reminder)
                let r = reminder
                modelContext.delete(r)
                dismiss()
            } label: {
                Label(String(localized: "delete_reminder"), systemImage: "trash")
            }
        }
        .onAppear {
            mapPosition = .region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: reminder.radius * 5,
                longitudinalMeters: reminder.radius * 5
            ))
        }
    }

    // MARK: - Edit View

    @ViewBuilder
    var editView: some View {
        Section(String(localized: "reminder_section")) {
            TextField(String(localized: "title_field"), text: $editTitle)
            TextField(String(localized: "note_optional"), text: $editNote)
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
                            if let title = item.name {
                                Text(title)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            if let coord = editCoordinate {
                Map(position: $mapPosition) {
                    Marker(
                        editLocationName.isEmpty ? String(localized: "trigger") : editLocationName,
                        coordinate: coord
                    )
                    MapCircle(center: coord, radius: editRadius)
                        .foregroundStyle(.blue.opacity(0.15))
                        .stroke(.blue, lineWidth: 1)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(true)

                HStack {
                    Text("Radius: \(Int(editRadius)) m")
                    Slider(value: $editRadius, in: 50...500, step: 50)
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
        search.start { response, _ in
            isSearching = false
            if let items = response?.mapItems {
                searchResults = Array(items.prefix(5))
            }
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        let coord = item.location.coordinate
        editCoordinate = coord
        editLocationName = item.name ?? ""
        searchText = editLocationName
        searchResults = []
        withAnimation {
            mapPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: editRadius * 5,
                longitudinalMeters: editRadius * 5
            ))
        }
    }

    // MARK: - Save

    private func startEditing() {
        editTitle = reminder.title
        editNote = reminder.note
        editLocationName = reminder.locationName
        editRadius = reminder.radius
        editCoordinate = coordinate
        searchText = reminder.locationName
        mapPosition = .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: reminder.radius * 5,
            longitudinalMeters: reminder.radius * 5
        ))
        isEditing = true
    }

    private func saveEdits() {
        LocationManager.shared.cancelNotification(for: reminder)
        reminder.title = editTitle
        reminder.note = editNote
        reminder.locationName = editLocationName
        reminder.radius = editRadius
        if let coord = editCoordinate {
            reminder.latitude = coord.latitude
            reminder.longitude = coord.longitude
        }
        LocationManager.shared.scheduleNotification(for: reminder)
        isEditing = false
    }
}
