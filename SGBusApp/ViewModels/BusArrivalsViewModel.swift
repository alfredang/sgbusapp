import Foundation
import CoreLocation
import Combine

@MainActor
final class BusArrivalsViewModel: ObservableObject {
    // Search + discovery
    @Published var searchText = ""
    @Published private(set) var searchResults: [BusStop] = []
    @Published private(set) var nearbyStops: [BusStop] = []

    // Selection + arrivals
    @Published private(set) var selectedStop: BusStop?
    @Published private(set) var services: [BusService] = []
    @Published var selectedServiceNo: String?          // filter: which bus the user picked
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var statusMessage: String?

    let store: BusStopStore
    let location: LocationManager
    private let arrivalsClient = LTADataMallClient()
    private let oneMap = OneMapClient()
    private var cancellables = Set<AnyCancellable>()

    init(store: BusStopStore = BusStopStore(), location: LocationManager = LocationManager()) {
        self.store = store
        self.location = location

        // React to GPS fixes by recomputing nearby stops.
        location.$coordinate
            .compactMap { $0 }
            .sink { [weak self] coordinate in self?.recomputeNearby(from: coordinate) }
            .store(in: &cancellables)

        // Re-render the view when the nested observable objects change.
        location.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        store.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// Bus numbers available at the selected stop (for the picker chips).
    var serviceNumbers: [String] { services.map(\.serviceNo) }

    /// Arrivals shown — filtered to the picked bus number when one is selected.
    var displayedServices: [BusService] {
        guard let selectedServiceNo else { return services }
        return services.filter { $0.serviceNo == selectedServiceNo }
    }

    // MARK: - Lifecycle

    private var didAutoLocate = false

    func onAppear() async {
        await store.load()
        if store.loadFailed {
            statusMessage = "Couldn't load the bus stop directory. Check your connection and pull to refresh."
        }
        if let coordinate = location.coordinate {
            // GPS already available — refresh nearby now that stops are loaded.
            recomputeNearby(from: coordinate)
        } else if !didAutoLocate && !location.isDenied {
            // Auto-detect the nearest stops on first launch.
            didAutoLocate = true
            location.request()
        }
    }

    // MARK: - Location

    func useCurrentLocation() {
        statusMessage = nil
        location.request()
    }

    func locationChanged(to coordinate: CLLocationCoordinate2D?) {
        guard let coordinate else { return }
        recomputeNearby(from: coordinate)
    }

    private func recomputeNearby(from coordinate: CLLocationCoordinate2D) {
        nearbyStops = store.nearest(to: coordinate, limit: 8)
        if selectedStop == nil, let closest = nearbyStops.first {
            select(closest)
        }
    }

    // MARK: - Search

    func searchTextChanged() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        searchResults = trimmed.isEmpty ? [] : store.search(trimmed)
    }

    /// Called when the user submits the search field. A 6-digit value is treated as a
    /// postal code (geocoded → nearest stops); a 5-digit value as a bus stop ID.
    func submitSearch() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let isAllDigits = trimmed.allSatisfy(\.isNumber)

        if isAllDigits && trimmed.count == 5, let stop = store.stop(code: trimmed) {
            select(stop)
            return
        }

        if isAllDigits && trimmed.count == 6 {
            statusMessage = "Finding stops near \(trimmed)…"
            do {
                if let coordinate = try await oneMap.coordinate(forPostalCode: trimmed) {
                    nearbyStops = store.nearest(to: coordinate, limit: 8)
                    statusMessage = nearbyStops.isEmpty ? "No bus stops found near that postal code." : nil
                    searchResults = []
                    if let closest = nearbyStops.first { select(closest) }
                } else {
                    statusMessage = "Couldn't find that postal code."
                }
            } catch {
                statusMessage = "Couldn't look up that postal code right now."
            }
            return
        }

        // Otherwise fall back to free-text matches; auto-select a single exact hit.
        searchResults = store.search(trimmed)
        if searchResults.count == 1 { select(searchResults[0]) }
    }

    // MARK: - Selection + arrivals

    func select(_ stop: BusStop) {
        selectedStop = stop
        selectedServiceNo = nil
        searchText = ""
        searchResults = []
        statusMessage = nil
        Task { await loadArrivals() }
    }

    func toggleService(_ serviceNo: String) {
        selectedServiceNo = (selectedServiceNo == serviceNo) ? nil : serviceNo
    }

    func loadArrivals() async {
        guard let stop = selectedStop else { return }
        isLoading = true
        errorMessage = nil
        do {
            services = try await arrivalsClient.fetchArrivals(busStopCode: stop.code)
                .sorted { $0.serviceNo.localizedStandardCompare($1.serviceNo) == .orderedAscending }
            lastUpdated = Date()
            if let selectedServiceNo, !serviceNumbers.contains(selectedServiceNo) {
                self.selectedServiceNo = nil
            }
        } catch {
            errorMessage = "Arrival data is not available right now."
        }
        isLoading = false
    }
}
