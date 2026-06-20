import Foundation

struct BusStop: Codable, Identifiable, Hashable {
    let code: String
    let roadName: String
    let description: String
    let latitude: Double
    let longitude: Double
    var distanceMeters: Double?

    var id: String { code }
    var title: String { description }
    var subtitle: String { "\(roadName) · \(code)" }

    var distanceText: String? {
        guard let distanceMeters else { return nil }
        if distanceMeters < 1000 { return "\(Int(distanceMeters.rounded())) m away" }
        return String(format: "%.1f km away", distanceMeters / 1000)
    }

    enum CodingKeys: String, CodingKey {
        case code = "BusStopCode"
        case roadName = "RoadName"
        case description = "Description"
        case latitude = "Latitude"
        case longitude = "Longitude"
    }
}

struct BusStopsResponse: Decodable {
    let value: [BusStop]
}

struct BusArrivalResponse: Decodable {
    let services: [BusService]

    enum CodingKeys: String, CodingKey {
        case services = "Services"
    }
}

struct BusService: Decodable, Identifiable {
    let serviceNo: String
    let operatorName: String
    let nextBus: NextBus
    let nextBus2: NextBus
    let nextBus3: NextBus

    var id: String { serviceNo }

    enum CodingKeys: String, CodingKey {
        case serviceNo = "ServiceNo"
        case operatorName = "Operator"
        case nextBus = "NextBus"
        case nextBus2 = "NextBus2"
        case nextBus3 = "NextBus3"
    }
}

struct NextBus: Decodable {
    let estimatedArrival: String
    let load: String
    let feature: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case estimatedArrival = "EstimatedArrival"
        case load = "Load"
        case feature = "Feature"
        case type = "Type"
    }

    var arrivalText: String {
        guard !estimatedArrival.isEmpty else { return "-" }
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        ]
        let date = formats.compactMap { format -> Date? in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter.date(from: estimatedArrival)
        }.first
        guard let date else { return "-" }
        let minutes = max(0, Int(ceil(date.timeIntervalSinceNow / 60)))
        if minutes == 0 { return "Arr" }
        return "\(minutes)m"
    }

    var loadText: String {
        switch load {
        case "SEA": return "Seats"
        case "SDA": return "Standing"
        case "LSD": return "Limited"
        default: return ""
        }
    }

    var typeText: String {
        switch type {
        case "SD": return "Single"
        case "DD": return "Double"
        case "BD": return "Bendy"
        default: return type
        }
    }
}
