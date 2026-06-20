import Foundation

final class LTADataMallClient: @unchecked Sendable {
    private let session: URLSession
    private let accountKey: String
    private let baseURL = URL(string: "https://datamall2.mytransport.sg/ltaodataservice")!

    init(session: URLSession = .shared) {
        self.session = session
        accountKey = Bundle.main.object(forInfoDictionaryKey: "LTAAccountKey") as? String ?? ""
    }

    private func request(path: String, queryItems: [URLQueryItem]) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(accountKey, forHTTPHeaderField: "AccountKey")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        return request
    }

    func fetchArrivals(busStopCode: String) async throws -> [BusService] {
        let req = request(path: "v3/BusArrival", queryItems: [URLQueryItem(name: "BusStopCode", value: busStopCode)])
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(BusArrivalResponse.self, from: data).services
    }

    /// LTA returns bus stops 500 at a time; page through with `$skip` until a short page.
    func fetchAllBusStops() async throws -> [BusStop] {
        var all: [BusStop] = []
        var skip = 0
        let pageSize = 500
        while true {
            let req = request(path: "BusStops", queryItems: [URLQueryItem(name: "$skip", value: String(skip))])
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let page = try JSONDecoder().decode(BusStopsResponse.self, from: data).value
            all.append(contentsOf: page)
            if page.count < pageSize { break }
            skip += pageSize
        }
        return all
    }
}
