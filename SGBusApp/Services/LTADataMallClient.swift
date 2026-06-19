import Foundation

final class LTADataMallClient: @unchecked Sendable {
    private let session: URLSession
    private let accountKey: String
    private let baseURL = URL(string: "https://datamall2.mytransport.sg/ltaodataservice")!

    init(session: URLSession = .shared) {
        self.session = session
        accountKey = Bundle.main.object(forInfoDictionaryKey: "LTAAccountKey") as? String ?? ""
    }

    func fetchArrivals(busStopCode: String) async throws -> [BusService] {
        var components = URLComponents(url: baseURL.appending(path: "v3/BusArrival"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "BusStopCode", value: busStopCode)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(accountKey, forHTTPHeaderField: "AccountKey")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(BusArrivalResponse.self, from: data).services
    }
}
