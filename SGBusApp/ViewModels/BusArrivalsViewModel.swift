import Foundation

@MainActor
final class BusArrivalsViewModel: ObservableObject {
    @Published var query = ""
    @Published var selectedStop = BusStop.popular[0]
    @Published private(set) var services: [BusService] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let client = LTADataMallClient()

    var filteredStops: [BusStop] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return BusStop.popular }
        return BusStop.popular.filter {
            $0.id.localizedCaseInsensitiveContains(trimmed) ||
            $0.roadName.localizedCaseInsensitiveContains(trimmed) ||
            $0.description.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func select(_ stop: BusStop) {
        selectedStop = stop
        query = ""
        Task { await loadArrivals() }
    }

    func loadArrivals() async {
        isLoading = true
        errorMessage = nil
        do {
            services = try await client.fetchArrivals(busStopCode: selectedStop.id)
                .sorted { $0.serviceNo.localizedStandardCompare($1.serviceNo) == .orderedAscending }
            lastUpdated = Date()
        } catch {
            errorMessage = "Arrival data is not available right now."
        }
        isLoading = false
    }
}
