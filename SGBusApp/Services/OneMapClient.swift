import Foundation
import CoreLocation

/// Geocodes a Singapore postal code to a coordinate using OneMap's public search API.
struct OneMapClient {
    func coordinate(forPostalCode postalCode: String) async throws -> CLLocationCoordinate2D? {
        var components = URLComponents(string: "https://www.onemap.gov.sg/api/common/elastic/search")!
        components.queryItems = [
            URLQueryItem(name: "searchVal", value: postalCode),
            URLQueryItem(name: "returnGeom", value: "Y"),
            URLQueryItem(name: "getAddrDetails", value: "N"),
            URLQueryItem(name: "pageNum", value: "1")
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }
        let decoded = try JSONDecoder().decode(OneMapSearchResponse.self, from: data)
        guard let first = decoded.results.first,
              let lat = Double(first.latitude),
              let lng = Double(first.longitude) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

private struct OneMapSearchResponse: Decodable {
    let results: [Result]

    struct Result: Decodable {
        let latitude: String
        let longitude: String

        enum CodingKeys: String, CodingKey {
            case latitude = "LATITUDE"
            case longitude = "LONGITUDE"
        }
    }
}
