import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import Combine

// MARK: - Completer Delegate

class CategoryCompleterDelegate: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results.filter {
            $0.subtitle == "Search Nearby" || $0.subtitle.isEmpty
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Completer error: \(error)")
    }
}

// MARK: - Reminder Mode

enum ReminderMode {
    case single, category
}

// MARK: - AddReminderView

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var mode: ReminderMode = .single
    @State private var title = ""
    @State private var note = ""
    @State private var triggerEvent: TriggerEvent = .onArrival

    // Single mode
    @State private var locationName = ""
    @State private var radius: Double = 100
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var isLoadingLocation = false

    // Category mode
    @State private var categoryQuery = ""
    @State private var categoryDisplayQuery = ""
    @State private var searchCenterName = ""
    @State private var searchCenterCoordinate: CLLocationCoordinate2D?
    @State private var searchRadiusKm: Double = 10
    @State private var foundLocations: [MKMapItem] = []
    @State private var isFindingLocations = false
    @State private var hasSearched = false
    @State private var isLoadingSearchCenter = false

    // Category completer
    @StateObject private var completerDelegate = CategoryCompleterDelegate()
    @State private var completer = MKLocalSearchCompleter()
    @State private var showCategoryCompletions = false

    // Shared search
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

    // Time rule
    @State private var timeRuleEnabled = false
    @State private var fromEnabled = false
    @State private var untilEnabled = false
    @State private var onlyOnEnabled = false
    @State private var fromDate = Calendar.current.startOfDay(for: Date())
    @State private var untilDate = Calendar.current.startOfDay(for: Date())
    @State private var onlyOnDate = Calendar.current.startOfDay(for: Date())

    var canSave: Bool {
        guard !title.isEmpty else { return false }
        if mode == .single { return selectedCoordinate != nil }
        return !categoryQuery.isEmpty && searchCenterCoordinate != nil
    }

    var isGerman: Bool {
        Locale.current.language.languageCode?.identifier == "de"
    }

    var staticSuggestions: [(display: String, query: String)] {
        isGerman
            ? [("Supermarkt", "Supermarket"), ("Apotheke", "Pharmacy"),
               ("Tankstelle", "Gas Station"), ("Bäckerei", "Bakery"), ("Drogerie", "Drugstore")]
            : [("Supermarket", "Supermarket"), ("Pharmacy", "Pharmacy"),
               ("Gas Station", "Gas Station"), ("Bakery", "Bakery"), ("Drugstore", "Drugstore")]
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Reminder info
                Section(String(localized: "reminder_section")) {
                    TextField(String(localized: "title_field"), text: $title)
                    TextField(String(localized: "note_optional"), text: $note)
                }

                // MARK: Mode picker
                Section {
                    Picker("Mode", selection: $mode) {
                        Label("Single Location", systemImage: "mappin.circle.fill")
                            .tag(ReminderMode.single)
                        Label("Category", systemImage: "square.grid.2x2.fill")
                            .tag(ReminderMode.category)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
                    .padding(.vertical, 4)
                } header: {
                    Text("Trigger Type")
                }

                // MARK: Trigger event picker
                Section {
                    Picker(
                        isGerman ? "Wann erinnern" : "When to Remind",
                        selection: $triggerEvent
                    ) {
                        Label(
                            isGerman ? "Bei Ankunft" : "On Arrival",
                            systemImage: "arrow.down.circle.fill"
                        ).tag(TriggerEvent.onArrival)
                        Label(
                            isGerman ? "Beim Verlassen" : "On Departure",
                            systemImage: "arrow.up.circle.fill"
                        ).tag(TriggerEvent.onDeparture)
                        Label(
                            isGerman ? "Beides" : "Both",
                            systemImage: "arrow.up.arrow.down.circle.fill"
                        ).tag(TriggerEvent.both)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
                    .padding(.vertical, 4)
                } header: {
                    Text(isGerman ? "Zeitpunkt" : "When")
                } footer: {
                    Text(triggerEventFooter).font(.caption)
                }

                // MARK: Time rule section
                timeRuleSection

                // MARK: Location
                if mode == .single {
                    singleLocationSection
                } else {
                    categorySection
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
            .onChange(of: mode) { _, _ in
                searchText = ""
                searchResults = []
                foundLocations = []
                hasSearched = false
            }
            .onChange(of: onlyOnEnabled) { _, on in
                // "Nur am" overrides range rules – disable them visually
                if on {
                    fromEnabled = false
                    untilEnabled = false
                }
            }
            .onAppear {
                completer.delegate = completerDelegate
                completer.resultTypes = .query
            }
        }
    }

    // MARK: - Time Rule Section

    var timeRuleSection: some View {
        Section {
            Toggle(
                isGerman ? "Zeitregel aktivieren" : "Enable Time Rule",
                isOn: $timeRuleEnabled
            )

            if timeRuleEnabled {
                // "Nur am" – exclusive with range rules
                Toggle(
                    isGerman ? "Nur am" : "Only on",
                    isOn: $onlyOnEnabled
                )
                if onlyOnEnabled {
                    DatePicker(
                        "",
                        selection: $onlyOnDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }

                Divider()

                // "Nicht vor"
                Toggle(
                    isGerman ? "Nicht vor" : "Not before",
                    isOn: $fromEnabled
                )
                .disabled(onlyOnEnabled)

                if fromEnabled && !onlyOnEnabled {
                    DatePicker(
                        "",
                        selection: $fromDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }

                // "Nicht nach"
                Toggle(
                    isGerman ? "Nicht nach" : "Not after",
                    isOn: $untilEnabled
                )
                .disabled(onlyOnEnabled)

                if untilEnabled && !onlyOnEnabled {
                    DatePicker(
                        "",
                        selection: $untilDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
            }
        } header: {
            Text(isGerman ? "Zeitregel (optional)" : "Time Rule (optional)")
        } footer: {
            if timeRuleEnabled {
                Text(timeRuleFooter).font(.caption)
            }
        }
    }

    // MARK: - Footer helpers

    private var triggerEventFooter: String {
        switch triggerEvent {
        case .onArrival:
            return isGerman
                ? "Du wirst benachrichtigt, wenn du den Ort betrittst."
                : "You'll be notified when you arrive at the location."
        case .onDeparture:
            return isGerman
                ? "Du wirst benachrichtigt, wenn du den Ort verlässt."
                : "You'll be notified when you leave the location."
        case .both:
            return isGerman
                ? "Du wirst beim Ankommen und beim Verlassen benachrichtigt."
                : "You'll be notified both when arriving and leaving."
        }
    }

    private var timeRuleFooter: String {
        var parts: [String] = []
        if onlyOnEnabled {
            let formatted = onlyOnDate.formatted(date: .long, time: .omitted)
            return isGerman
                ? "Erinnerung wird nur am \(formatted) ausgelöst."
                : "Reminder fires only on \(formatted)."
        }
        if fromEnabled {
            let formatted = fromDate.formatted(date: .long, time: .omitted)
            parts.append(isGerman ? "Nicht vor dem \(formatted)" : "Not before \(formatted)")
        }
        if untilEnabled {
            let formatted = untilDate.formatted(date: .long, time: .omitted)
            parts.append(isGerman ? "Nicht nach dem \(formatted)" : "Not after \(formatted)")
        }
        return parts.isEmpty
            ? (isGerman ? "Keine Zeitregel gesetzt." : "No time rule set.")
            : parts.joined(separator: isGerman ? " · " : " · ")
    }

    // MARK: - Single Location Section

    var singleLocationSection: some View {
        Section(String(localized: "location_trigger")) {
            Button {
                useCurrentLocation()
            } label: {
                HStack {
                    if isLoadingLocation {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "location.fill").foregroundStyle(.blue)
                    }
                    Text(isGerman ? "Meinen Standort verwenden" : "Use My Location")
                        .foregroundStyle(.blue)
                }
            }
            .disabled(isLoadingLocation)

            searchField(placeholder: String(localized: "search_placeholder"))

            if isSearching {
                HStack { Spacer(); ProgressView(); Spacer() }
            }

            ForEach(0..<searchResults.count, id: \.self) { i in
                let item = searchResults[i]
                Button { selectSingleLocation(item) } label: {
                    locationRow(item: item)
                }
            }

            if let coord = selectedCoordinate {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: radius * 5,
                    longitudinalMeters: radius * 5
                )))) {
                    Marker(locationName.isEmpty ? String(localized: "trigger") : locationName, coordinate: coord)
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
                emptyMapPlaceholder(icon: "mappin.and.ellipse", text: String(localized: "search_location_hint"))
            }
        }
    }

    // MARK: - Category Section

    var categorySection: some View {
        Group {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "tag.fill").foregroundStyle(.blue)
                    TextField(
                        isGerman ? "z. B. Apotheke, Supermarkt…" : "e.g. Pharmacy, Supermarket…",
                        text: $categoryDisplayQuery
                    )
                    .autocorrectionDisabled()
                    .onChange(of: categoryDisplayQuery) { _, new in
                        categoryQuery = new
                        hasSearched = false
                        foundLocations = []
                        if new.isEmpty {
                            completerDelegate.results = []
                            showCategoryCompletions = false
                        } else {
                            completer.queryFragment = new
                            showCategoryCompletions = true
                        }
                    }
                    if !categoryDisplayQuery.isEmpty {
                        Button {
                            categoryDisplayQuery = ""
                            categoryQuery = ""
                            completerDelegate.results = []
                            showCategoryCompletions = false
                            foundLocations = []
                            hasSearched = false
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(staticSuggestions, id: \.display) { s in
                            Button {
                                categoryDisplayQuery = s.display
                                categoryQuery = s.query
                                showCategoryCompletions = false
                                completerDelegate.results = []
                            } label: {
                                Text(s.display)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        categoryDisplayQuery == s.display ? Color.blue : Color.blue.opacity(0.1),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(categoryDisplayQuery == s.display ? .white : .blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))

                if showCategoryCompletions && !completerDelegate.results.isEmpty {
                    ForEach(completerDelegate.results.prefix(5), id: \.self) { completion in
                        Button {
                            categoryDisplayQuery = completion.title
                            categoryQuery = completion.title
                            showCategoryCompletions = false
                            completerDelegate.results = []
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(completion.title).foregroundStyle(.primary)
                            }
                        }
                    }
                }
            } header: {
                Text("Category")
            } footer: {
                Text(isGerman
                     ? "Du wirst an jedem passenden Ort im Suchbereich erinnert."
                     : "You'll be reminded at every matching location in the search area.")
                    .font(.caption)
            }

            Section {
                Button {
                    useCurrentLocationAsCenter()
                } label: {
                    HStack {
                        if isLoadingSearchCenter {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "location.fill").foregroundStyle(.blue)
                        }
                        Text(isGerman ? "Meinen Standort als Mittelpunkt" : "Use My Location as Center")
                            .foregroundStyle(.blue)
                    }
                }
                .disabled(isLoadingSearchCenter)

                searchField(placeholder: isGerman ? "Mittelpunkt suchen…" : "Search center location…")

                if isSearching {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }

                ForEach(0..<searchResults.count, id: \.self) { i in
                    let item = searchResults[i]
                    Button { selectSearchCenter(item) } label: {
                        locationRow(item: item)
                    }
                }

                if let coord = searchCenterCoordinate {
                    Map(position: .constant(.region(MKCoordinateRegion(
                        center: coord,
                        latitudinalMeters: searchRadiusKm * 1000 * 2.5,
                        longitudinalMeters: searchRadiusKm * 1000 * 2.5
                    )))) {
                        Annotation(searchCenterName, coordinate: coord) {
                            ZStack {
                                Circle().fill(.blue).frame(width: 32, height: 32)
                                Image(systemName: "scope")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        MapCircle(center: coord, radius: searchRadiusKm * 1000)
                            .foregroundStyle(.blue.opacity(0.08))
                            .stroke(.blue.opacity(0.4), lineWidth: 1.5)
                        ForEach(foundLocations.prefix(20), id: \.self) { item in
                            Marker(item.name ?? "", coordinate: item.location.coordinate)
                                .tint(.orange)
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(true)

                    HStack {
                        Text(isGerman ? "Suchradius: \(Int(searchRadiusKm)) km" : "Search radius: \(Int(searchRadiusKm)) km")
                        Slider(value: $searchRadiusKm, in: 1...50, step: 1)
                            .onChange(of: searchRadiusKm) { _, _ in
                                foundLocations = []
                                hasSearched = false
                            }
                    }

                    Button {
                        previewCategoryLocations()
                    } label: {
                        if isFindingLocations {
                            HStack { ProgressView(); Text(isGerman ? "Suche läuft…" : "Searching…") }
                        } else {
                            Label(isGerman ? "Orte suchen" : "Find Locations", systemImage: "magnifyingglass.circle")
                        }
                    }
                    .disabled(categoryQuery.isEmpty || isFindingLocations)

                } else {
                    emptyMapPlaceholder(
                        icon: "scope",
                        text: isGerman ? "Mittelpunkt suchen" : "Search for a center location"
                    )
                }

            } header: {
                Text(isGerman ? "Suchmittelpunkt" : "Search Center")
            } footer: {
                Text(isGerman
                     ? "Future Reminder überwacht die nächstgelegenen Orte von diesem Punkt aus."
                     : "Future Reminder will monitor the nearest locations from this point.")
                    .font(.caption)
            }

            if hasSearched {
                Section {
                    if foundLocations.isEmpty {
                        Label(
                            isGerman ? "Keine Orte gefunden" : "No locations found",
                            systemImage: "exclamationmark.circle"
                        )
                        .foregroundStyle(.orange)
                    } else {
                        Label(
                            isGerman
                                ? "\(foundLocations.count) Orte gefunden — \(min(foundLocations.count, 20)) Geofences werden registriert"
                                : "\(foundLocations.count) locations found — \(min(foundLocations.count, 20)) geofences will be registered",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                        .font(.subheadline)

                        ForEach(foundLocations.prefix(20), id: \.self) { item in
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "—").font(.subheadline)
                                    if let title = item.placemark.title, !title.isEmpty {
                                        Text(title).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text(isGerman ? "Gefundene Orte" : "Found Locations")
                }
            }
        }
    }

    // MARK: - Shared UI helpers

    func searchField(placeholder: String) -> some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $searchText)
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
    }

    func emptyMapPlaceholder(icon: String, text: String) -> some View {
        Map(position: $mapPosition)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .center) {
                VStack(spacing: 6) {
                    Image(systemName: icon).font(.title2).foregroundStyle(.blue)
                    Text(text).font(.caption).foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
    }

    func locationRow(item: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name ?? String(localized: "unknown")).foregroundStyle(.primary)
            if let title = item.placemark.title, !title.isEmpty {
                Text(title).foregroundStyle(.secondary).font(.caption)
            }
        }
    }

    // MARK: - Current location helpers

    private func useCurrentLocation() {
        isLoadingLocation = true
        let manager = CLLocationManager()
        guard let coord = manager.location?.coordinate else {
            isLoadingLocation = false
            return
        }
        Task {
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(loc)
            await MainActor.run {
                isLoadingLocation = false
                let name = placemarks?.first?.name
                    ?? placemarks?.first?.locality
                    ?? (isGerman ? "Mein Standort" : "My Location")
                selectedCoordinate = coord
                locationName = name
                searchText = name
                searchResults = []
            }
        }
    }

    private func useCurrentLocationAsCenter() {
        isLoadingSearchCenter = true
        let manager = CLLocationManager()
        guard let coord = manager.location?.coordinate else {
            isLoadingSearchCenter = false
            return
        }
        Task {
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(loc)
            await MainActor.run {
                isLoadingSearchCenter = false
                let name = placemarks?.first?.locality
                    ?? placemarks?.first?.name
                    ?? (isGerman ? "Mein Standort" : "My Location")
                searchCenterCoordinate = coord
                searchCenterName = name
                searchText = name
                searchResults = []
                foundLocations = []
                hasSearched = false
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
        MKLocalSearch(request: request).start { response, _ in
            isSearching = false
            if let items = response?.mapItems {
                searchResults = Array(items.prefix(5))
            }
        }
    }

    private func selectSingleLocation(_ item: MKMapItem) {
        selectedCoordinate = item.location.coordinate
        locationName = item.name ?? ""
        searchText = locationName
        searchResults = []
    }

    private func selectSearchCenter(_ item: MKMapItem) {
        searchCenterCoordinate = item.location.coordinate
        searchCenterName = item.name ?? ""
        searchText = searchCenterName
        searchResults = []
        foundLocations = []
        hasSearched = false
    }

    private func previewCategoryLocations() {
        guard let coord = searchCenterCoordinate, !categoryQuery.isEmpty else { return }
        isFindingLocations = true
        foundLocations = []
        hasSearched = false
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = categoryQuery
        request.resultTypes = [.pointOfInterest]
        request.region = MKCoordinateRegion(
            center: coord,
            latitudinalMeters: searchRadiusKm * 1000 * 2,
            longitudinalMeters: searchRadiusKm * 1000 * 2
        )
        MKLocalSearch(request: request).start { response, _ in
            isFindingLocations = false
            hasSearched = true
            let items = response?.mapItems ?? []
            let ref = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            foundLocations = items.sorted {
                let a = CLLocation(latitude: $0.location.coordinate.latitude, longitude: $0.location.coordinate.longitude)
                let b = CLLocation(latitude: $1.location.coordinate.latitude, longitude: $1.location.coordinate.longitude)
                return ref.distance(from: a) < ref.distance(from: b)
            }
        }
    }

    // MARK: - Save

    private func save() {
        // Resolve time rules
        let resolvedFrom: Date?    = timeRuleEnabled && fromEnabled && !onlyOnEnabled ? fromDate : nil
        let resolvedUntil: Date?   = timeRuleEnabled && untilEnabled && !onlyOnEnabled ? untilDate : nil
        let resolvedOnlyOn: Date?  = timeRuleEnabled && onlyOnEnabled ? onlyOnDate : nil

        if mode == .single {
            guard let coord = selectedCoordinate else { return }
            let reminder = Reminder(
                title: title, note: note,
                latitude: coord.latitude, longitude: coord.longitude,
                radius: radius, locationName: locationName,
                triggerEvent: triggerEvent,
                activeFrom: resolvedFrom,
                activeUntil: resolvedUntil,
                activeOnlyOn: resolvedOnlyOn
            )
            modelContext.insert(reminder)
            LocationManager.shared.scheduleNotification(for: reminder)
        } else {
            guard let center = searchCenterCoordinate, !categoryQuery.isEmpty else { return }
            let reminder = Reminder(
                title: title, note: note,
                isCategory: true,
                categoryQuery: categoryQuery,
                searchCenterLat: center.latitude,
                searchCenterLon: center.longitude,
                searchRadiusKm: searchRadiusKm,
                triggerEvent: triggerEvent,
                activeFrom: resolvedFrom,
                activeUntil: resolvedUntil,
                activeOnlyOn: resolvedOnlyOn
            )
            modelContext.insert(reminder)
            LocationManager.shared.scheduleNotification(for: reminder)
        }
        dismiss()
    }
}
