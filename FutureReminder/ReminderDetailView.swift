import SwiftUI
import MapKit
import CoreLocation
import SwiftData

struct ReminderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var reminder: Reminder

    @State private var isEditing = false

    // Shared edit state
    @State private var editTitle = ""
    @State private var editNote = ""
    @State private var editTriggerEvent: TriggerEvent = .onArrival

    // Single location edit state
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

    // Category edit state
    @State private var editCategoryQuery = ""
    @State private var editSearchCenterName = ""
    @State private var editSearchCenterCoordinate: CLLocationCoordinate2D?
    @State private var editSearchRadiusKm: Double = 10

    // Time rule edit state
    @State private var timeRuleEnabled = false
    @State private var fromEnabled = false
    @State private var untilEnabled = false
    @State private var onlyOnEnabled = false
    @State private var fromDate = Calendar.current.startOfDay(for: Date())
    @State private var untilDate = Calendar.current.startOfDay(for: Date())
    @State private var onlyOnDate = Calendar.current.startOfDay(for: Date())

    var isGerman: Bool {
        Locale.current.language.languageCode?.identifier == "de"
    }

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
        // Reminder info
        Section(String(localized: "reminder_section")) {
            LabeledContent(String(localized: "title_field"), value: reminder.title)
            if !reminder.note.isEmpty {
                LabeledContent(String(localized: "note_optional"), value: reminder.note)
            }
            LabeledContent(String(localized: "status"),
                value: reminder.isDone ? String(localized: "status_done") : String(localized: "status_open"))
        }

        // Trigger event
        Section {
            LabeledContent(isGerman ? "Zeitpunkt" : "When") {
                Text(triggerEventLabel(reminder.triggerEvent))
                    .foregroundStyle(.secondary)
            }
        }

        // Time rule
        if reminder.hasTimeRule {
            Section(isGerman ? "Zeitregel" : "Time Rule") {
                if let onlyOn = reminder.activeOnlyOn {
                    LabeledContent(isGerman ? "Nur am" : "Only on",
                        value: onlyOn.formatted(date: .long, time: .omitted))
                }
                if let from = reminder.activeFrom {
                    LabeledContent(isGerman ? "Nicht vor" : "Not before",
                        value: from.formatted(date: .long, time: .omitted))
                }
                if let until = reminder.activeUntil {
                    LabeledContent(isGerman ? "Nicht nach" : "Not after",
                        value: until.formatted(date: .long, time: .omitted))
                }
            }
        }

        // Location
        if reminder.isCategory {
            Section(isGerman ? "Kategorie" : "Category") {
                LabeledContent(isGerman ? "Suche" : "Query", value: reminder.categoryQuery)
                LabeledContent(isGerman ? "Suchradius" : "Search radius",
                    value: "\(Int(reminder.searchRadiusKm)) km")

                let center = CLLocationCoordinate2D(
                    latitude: reminder.searchCenterLat,
                    longitude: reminder.searchCenterLon
                )
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: center,
                    latitudinalMeters: reminder.searchRadiusKm * 1000 * 2.5,
                    longitudinalMeters: reminder.searchRadiusKm * 1000 * 2.5
                )))) {
                    Annotation("", coordinate: center) {
                        ZStack {
                            Circle().fill(.blue).frame(width: 28, height: 28)
                            Image(systemName: "scope").foregroundStyle(.white)
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    MapCircle(center: center, radius: reminder.searchRadiusKm * 1000)
                        .foregroundStyle(.blue.opacity(0.08))
                        .stroke(.blue.opacity(0.4), lineWidth: 1.5)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(true)
            }
        } else {
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
        }

        // Actions
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
                modelContext.delete(reminder)
                dismiss()
            } label: {
                Label(String(localized: "delete_reminder"), systemImage: "trash")
            }
        }
    }

    // MARK: - Edit View

    @ViewBuilder
    var editView: some View {
        // Reminder info
        Section(String(localized: "reminder_section")) {
            TextField(String(localized: "title_field"), text: $editTitle)
            TextField(String(localized: "note_optional"), text: $editNote)
        }

        // Trigger event picker
        Section {
            Picker(isGerman ? "Wann erinnern" : "When to Remind", selection: $editTriggerEvent) {
                Label(isGerman ? "Bei Ankunft" : "On Arrival",
                      systemImage: "arrow.down.circle.fill").tag(TriggerEvent.onArrival)
                Label(isGerman ? "Beim Verlassen" : "On Departure",
                      systemImage: "arrow.up.circle.fill").tag(TriggerEvent.onDeparture)
                Label(isGerman ? "Beides" : "Both",
                      systemImage: "arrow.up.arrow.down.circle.fill").tag(TriggerEvent.both)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(.init())
            .padding(.vertical, 4)
        } header: {
            Text(isGerman ? "Zeitpunkt" : "When")
        }

        // Time rule
        Section {
            Toggle(isGerman ? "Zeitregel aktivieren" : "Enable Time Rule", isOn: $timeRuleEnabled)

            if timeRuleEnabled {
                Toggle(isGerman ? "Nur am" : "Only on", isOn: $onlyOnEnabled)
                if onlyOnEnabled {
                    DatePicker("", selection: $onlyOnDate, displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden()
                }

                Divider()

                Toggle(isGerman ? "Nicht vor" : "Not before", isOn: $fromEnabled)
                    .disabled(onlyOnEnabled)
                if fromEnabled && !onlyOnEnabled {
                    DatePicker("", selection: $fromDate, displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden()
                }

                Toggle(isGerman ? "Nicht nach" : "Not after", isOn: $untilEnabled)
                    .disabled(onlyOnEnabled)
                if untilEnabled && !onlyOnEnabled {
                    DatePicker("", selection: $untilDate, displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden()
                }
            }
        } header: {
            Text(isGerman ? "Zeitregel (optional)" : "Time Rule (optional)")
        }
        .onChange(of: onlyOnEnabled) { _, on in
            if on { fromEnabled = false; untilEnabled = false }
        }

        // Location (category vs single)
        if reminder.isCategory {
            categoryEditSection
        } else {
            singleEditSection
        }
    }

    // MARK: - Single location edit

    @ViewBuilder
    var singleEditSection: some View {
        Section(String(localized: "location_trigger")) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(String(localized: "search_placeholder"), text: $searchText)
                    .autocorrectionDisabled()
                    .onSubmit { searchLocation() }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }

            if isSearching {
                HStack { Spacer(); ProgressView(); Spacer() }
            }

            ForEach(0..<searchResults.count, id: \.self) { index in
                let item = searchResults[index]
                Button { selectLocation(item) } label: {
                    Text(item.name ?? String(localized: "unknown")).foregroundStyle(.primary)
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

    // MARK: - Category edit

    @ViewBuilder
    var categoryEditSection: some View {
        Section(isGerman ? "Kategorie" : "Category") {
            HStack {
                Image(systemName: "tag.fill").foregroundStyle(.blue)
                TextField(
                    isGerman ? "z. B. Apotheke, Supermarkt…" : "e.g. Pharmacy, Supermarket…",
                    text: $editCategoryQuery
                )
                .autocorrectionDisabled()
            }
        }

        Section(isGerman ? "Suchmittelpunkt" : "Search Center") {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(
                    isGerman ? "Mittelpunkt suchen…" : "Search center location…",
                    text: $searchText
                )
                .autocorrectionDisabled()
                .onSubmit { searchLocation() }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }

            if isSearching {
                HStack { Spacer(); ProgressView(); Spacer() }
            }

            ForEach(0..<searchResults.count, id: \.self) { index in
                let item = searchResults[index]
                Button { selectSearchCenter(item) } label: {
                    Text(item.name ?? String(localized: "unknown")).foregroundStyle(.primary)
                }
            }

            if let coord = editSearchCenterCoordinate {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: editSearchRadiusKm * 1000 * 2.5,
                    longitudinalMeters: editSearchRadiusKm * 1000 * 2.5
                )))) {
                    Annotation(editSearchCenterName, coordinate: coord) {
                        ZStack {
                            Circle().fill(.blue).frame(width: 28, height: 28)
                            Image(systemName: "scope").foregroundStyle(.white)
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    MapCircle(center: coord, radius: editSearchRadiusKm * 1000)
                        .foregroundStyle(.blue.opacity(0.08))
                        .stroke(.blue.opacity(0.4), lineWidth: 1.5)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(true)

                HStack {
                    Text(isGerman
                         ? "Suchradius: \(Int(editSearchRadiusKm)) km"
                         : "Search radius: \(Int(editSearchRadiusKm)) km")
                    Slider(value: $editSearchRadiusKm, in: 1...50, step: 1)
                }
            }
        }
    }

    // MARK: - Search helpers

    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        searchResults = []
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.address, .pointOfInterest]
        MKLocalSearch(request: request).start { response, _ in
            isSearching = false
            searchResults = Array((response?.mapItems ?? []).prefix(5))
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

    private func selectSearchCenter(_ item: MKMapItem) {
        editSearchCenterCoordinate = item.location.coordinate
        editSearchCenterName = item.name ?? ""
        searchText = editSearchCenterName
        searchResults = []
    }

    // MARK: - Start editing

    private func startEditing() {
        editTitle        = reminder.title
        editNote         = reminder.note
        editTriggerEvent = reminder.triggerEvent

        // Time rules
        timeRuleEnabled = reminder.hasTimeRule
        if let onlyOn = reminder.activeOnlyOn {
            onlyOnEnabled = true
            onlyOnDate    = onlyOn
        } else {
            onlyOnEnabled = false
            if let from = reminder.activeFrom {
                fromEnabled = true
                fromDate    = from
            }
            if let until = reminder.activeUntil {
                untilEnabled = true
                untilDate    = until
            }
        }

        if reminder.isCategory {
            editCategoryQuery            = reminder.categoryQuery
            editSearchRadiusKm           = reminder.searchRadiusKm
            editSearchCenterCoordinate   = CLLocationCoordinate2D(
                latitude: reminder.searchCenterLat,
                longitude: reminder.searchCenterLon
            )
            editSearchCenterName         = ""  // no reverse geocode needed for display
        } else {
            editLocationName  = reminder.locationName
            editRadius        = reminder.radius
            editCoordinate    = coordinate
            searchText        = reminder.locationName
            mapPosition       = .region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: reminder.radius * 5,
                longitudinalMeters: reminder.radius * 5
            ))
        }

        isEditing = true
    }

    // MARK: - Save edits

    private func saveEdits() {
        LocationManager.shared.cancelNotification(for: reminder)

        reminder.title        = editTitle
        reminder.note         = editNote
        reminder.triggerEvent = editTriggerEvent

        // Time rules
        if timeRuleEnabled {
            reminder.activeOnlyOn = onlyOnEnabled ? onlyOnDate : nil
            reminder.activeFrom   = (!onlyOnEnabled && fromEnabled)  ? fromDate  : nil
            reminder.activeUntil  = (!onlyOnEnabled && untilEnabled) ? untilDate : nil
        } else {
            reminder.activeOnlyOn = nil
            reminder.activeFrom   = nil
            reminder.activeUntil  = nil
        }

        if reminder.isCategory {
            reminder.categoryQuery  = editCategoryQuery
            reminder.searchRadiusKm = editSearchRadiusKm
            if let coord = editSearchCenterCoordinate {
                reminder.searchCenterLat = coord.latitude
                reminder.searchCenterLon = coord.longitude
            }
        } else {
            reminder.locationName = editLocationName
            reminder.radius       = editRadius
            if let coord = editCoordinate {
                reminder.latitude  = coord.latitude
                reminder.longitude = coord.longitude
            }
        }

        LocationManager.shared.scheduleNotification(for: reminder)
        isEditing = false
    }

    // MARK: - Helpers

    private func triggerEventLabel(_ event: TriggerEvent) -> String {
        switch event {
        case .onArrival:   return isGerman ? "Bei Ankunft"     : "On Arrival"
        case .onDeparture: return isGerman ? "Beim Verlassen"  : "On Departure"
        case .both:        return isGerman ? "Beides"          : "Both"
        }
    }
}
