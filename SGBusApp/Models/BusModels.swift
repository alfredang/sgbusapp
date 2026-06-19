import Foundation

struct BusStop: Identifiable, Hashable {
    let id: String
    let roadName: String
    let description: String

    var title: String { description }
    var subtitle: String { "\(roadName) · \(id)" }

    static let popular: [BusStop] = [
        .init(id: "01012", roadName: "Victoria St", description: "Hotel Grand Pacific"),
        .init(id: "01013", roadName: "Victoria St", description: "St. Joseph's Ch"),
        .init(id: "01112", roadName: "Victoria St", description: "Bugis Stn Exit A"),
        .init(id: "02049", roadName: "Bras Basah Rd", description: "Raffles Hotel"),
        .init(id: "02151", roadName: "Stamford Rd", description: "Capitol Bldg"),
        .init(id: "03217", roadName: "Orchard Rd", description: "Opp Somerset Stn"),
        .init(id: "09047", roadName: "Bayfront Ave", description: "Marina Bay Sands"),
        .init(id: "14141", roadName: "Holland Rd", description: "Holland Village"),
        .init(id: "22009", roadName: "Jurong Gateway Rd", description: "Jurong East Int"),
        .init(id: "75009", roadName: "Woodlands Rd", description: "Bt Panjang Temp Bus Pk")
    ]
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
