import Foundation

/// Persists the user's favorite bus stops in UserDefaults (as JSON).
@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var stops: [BusStop] = []

    private let key = "favorite_bus_stops"

    init() { load() }

    func isFavorite(_ code: String) -> Bool {
        stops.contains { $0.code == code }
    }

    func toggle(_ stop: BusStop) {
        if let index = stops.firstIndex(where: { $0.code == stop.code }) {
            stops.remove(at: index)
        } else {
            var saved = stop
            saved.distanceMeters = nil          // distance is location-dependent; don't persist it
            stops.append(saved)
        }
        save()
    }

    func remove(at offsets: IndexSet) {
        stops.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BusStop].self, from: data) else { return }
        stops = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stops) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
