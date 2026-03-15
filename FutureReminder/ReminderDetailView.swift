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
        .navigationTitle(isEditing ? "Edit Reminder" : reminder.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveEdits()
                    }
                    .fontWeight(.semibold)
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isEditing = false
                    }
                }
            }
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    var detailView: some View {
        Section("Reminder") {
            LabeledContent("Title", value: reminder.title)
            if !reminder.note.isEmpty {
                LabeledContent("Note", value: reminder.note)
            }
            LabeledContent("Status", value: reminder.isDone ? "Done ✓" : "Open")
        }

        Section("Location Trigger") {
            if !reminder.locationName.isEmpty {
                Label(reminder.locationName, systemImage: "mappin.circle")
            }
            LabeledContent("Radius", value: "\(Int(reminder.radius)) m")

            Map {
                Marker(
                    reminder.locationName.isEmpty ? "Trigger" : reminder.locationName,
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
                    Label("Mark as Done", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }

            Button(role: .destructive) {
                LocationManager.shared.cancelNotification(for: reminder)
                let r = reminder
                modelContext.delete(r)
                dismiss()
            } label: {
                Label("Delete Reminder", systemImage: "trash")
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
        Section("Reminder") {
            TextField("Title", text: $editTitle)
            TextField("Note (optional)", text: $editNote)
        }

        Section("Location Trigger") {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search address or place...", text: $searchText)
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
                            Text(item.placemark.thoroughfare ?? item.placemark.locality ?? "")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }

            if let coord = editCoordinate {
                Map(position: $mapPosition) {
                    Marker(
                        editLocationName.isEmpty ? "Trigger" : editLocationName,
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
        let coord = item.placemark.coordinate
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

    // MARK: - Save Edits

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
