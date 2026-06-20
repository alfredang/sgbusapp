import Foundation
import CoreLocation

/// Loads the full LTA bus-stop directory (with coordinates), caches it on disk, and
/// answers nearest-by-GPS, exact-code lookup, and free-text search queries.
@MainActor
final class BusStopStore: ObservableObject {
    @Published private(set) var isLoaded = false
    @Published private(set) var loadFailed = false

    private var stops: [BusStop] = []
    private var byCode: [String: BusStop] = [:]
    private let client: LTADataMallClient

    init(client: LTADataMallClient = LTADataMallClient()) {
        self.client = client
    }

    func load() async {
        if isLoaded { return }
        if let cached = Self.readCache(), !cached.isEmpty {
            apply(cached)
        }
        if stops.isEmpty {
            do {
                let fetched = try await client.fetchAllBusStops()
                if fetched.isEmpty {
                    loadFailed = true
                } else {
                    apply(fetched)
                    Self.writeCache(fetched)
                }
            } catch {
                loadFailed = stops.isEmpty
            }
        }
    }

    private func apply(_ newStops: [BusStop]) {
        stops = newStops
        byCode = Dictionary(newStops.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
        isLoaded = true
        loadFailed = false
    }

    func stop(code: String) -> BusStop? { byCode[code] }

    func nearest(to coordinate: CLLocationCoordinate2D, limit: Int = 8) -> [BusStop] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return stops
            .map { stop -> BusStop in
                var copy = stop
                copy.distanceMeters = origin.distance(
                    from: CLLocation(latitude: stop.latitude, longitude: stop.longitude))
                return copy
            }
            .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
            .prefix(limit)
            .map { $0 }
    }

    func search(_ text: String, limit: Int = 25) -> [BusStop] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let matches = stops.filter {
            $0.code.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.roadName.localizedCaseInsensitiveContains(query)
        }
        // Exact code prefix matches first, then alphabetical by description.
        return matches.sorted { lhs, rhs in
            let lp = lhs.code.hasPrefix(query), rp = rhs.code.hasPrefix(query)
            if lp != rp { return lp }
            return lhs.description.localizedStandardCompare(rhs.description) == .orderedAscending
        }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - Disk cache

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("busstops.json")
    }

    private static func readCache() -> [BusStop]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode([BusStop].self, from: data)
    }

    private static func writeCache(_ stops: [BusStop]) {
        guard let data = try? JSONEncoder().encode(stops) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
