import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BusArrivalsViewModel()
    @StateObject private var favorites = FavoritesStore()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ArrivalsView(viewModel: viewModel, favorites: favorites)
                .tabItem { Label("Arrivals", systemImage: "bus.fill") }
                .tag(0)

            FavoritesView(viewModel: viewModel, favorites: favorites, onSelect: { selectedTab = 0 })
                .tabItem { Label("Favorites", systemImage: "star.fill") }
                .tag(1)

            FeedbackView()
                .tabItem { Label("Feedback", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(2)

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle.fill") }
                .tag(3)
        }
        .tint(.green)
    }
}

// MARK: - Arrivals tab

struct ArrivalsView: View {
    @ObservedObject var viewModel: BusArrivalsViewModel
    @ObservedObject var favorites: FavoritesStore

    var body: some View {
        NavigationStack {
            List {
                searchSection

                if viewModel.searchText.isEmpty, viewModel.selectedStop != nil {
                    arrivalsSection
                }

                if !viewModel.searchText.isEmpty {
                    searchResultsSection
                } else if !viewModel.nearbyStops.isEmpty {
                    nearbySection
                }

                if let statusMessage = viewModel.statusMessage {
                    Section { Text(statusMessage).font(.callout).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("SG Bus Live")
            .task { await viewModel.onAppear() }
            .refreshable { await viewModel.loadArrivals() }
        }
    }

    private var searchSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Postal code or bus stop ID", text: $viewModel.searchText)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onChange(of: viewModel.searchText) { _, _ in viewModel.searchTextChanged() }
                    .onSubmit { Task { await viewModel.submitSearch() } }
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.searchTextChanged()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                viewModel.useCurrentLocation()
            } label: {
                HStack {
                    Label("Use my location", systemImage: "location.fill")
                    Spacer()
                    if viewModel.location.isRequesting { ProgressView() }
                }
            }
            .disabled(viewModel.location.isRequesting)

            if let locationError = viewModel.location.errorMessage, viewModel.nearbyStops.isEmpty {
                Text(locationError).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var searchResultsSection: some View {
        Section("Results") {
            if viewModel.searchResults.isEmpty {
                Text("No matching stops. Try a 5-digit stop ID, a 6-digit postal code, or a road name.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.searchResults) { stop in
                    StopRow(stop: stop, isSelected: stop.code == viewModel.selectedStop?.code) {
                        viewModel.select(stop)
                    }
                }
            }
        }
    }

    private var nearbySection: some View {
        Section("Nearby stops") {
            ForEach(viewModel.nearbyStops) { stop in
                StopRow(stop: stop, isSelected: stop.code == viewModel.selectedStop?.code) {
                    viewModel.select(stop)
                }
            }
        }
    }

    private var arrivalsSection: some View {
        Section {
            if let stop = viewModel.selectedStop {
                StopHeader(stop: stop, updatedAt: viewModel.lastUpdated)

                Button {
                    favorites.toggle(stop)
                } label: {
                    let saved = favorites.isFavorite(stop.code)
                    Label(saved ? "Saved to Favorites" : "Save to Favorites",
                          systemImage: saved ? "star.fill" : "star")
                        .foregroundStyle(saved ? .yellow : .green)
                }
            }

            if !viewModel.serviceNumbers.isEmpty {
                ServiceFilterRow(
                    serviceNumbers: viewModel.serviceNumbers,
                    selected: viewModel.selectedServiceNo,
                    onTap: { viewModel.toggleService($0) }
                )
            }

            if viewModel.isLoading && viewModel.services.isEmpty {
                ProgressView("Loading arrivals")
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(errorMessage, systemImage: "wifi.exclamationmark")
            } else if viewModel.services.isEmpty {
                ContentUnavailableView("No arrivals listed", systemImage: "bus")
            } else {
                ForEach(viewModel.displayedServices) { service in
                    ServiceArrivalRow(service: service)
                }
            }

            Button {
                Task { await viewModel.loadArrivals() }
            } label: {
                Label(viewModel.isLoading ? "Refreshing" : "Refresh arrivals", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        } header: {
            Text(viewModel.selectedServiceNo == nil ? "Arrivals" : "Bus \(viewModel.selectedServiceNo!)")
        }
    }
}

// MARK: - Favorites tab

struct FavoritesView: View {
    @ObservedObject var viewModel: BusArrivalsViewModel
    @ObservedObject var favorites: FavoritesStore
    let onSelect: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if favorites.stops.isEmpty {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "star",
                        description: Text("Open a stop on the Arrivals tab and tap “Save to Favorites” to add it here.")
                    )
                } else {
                    ForEach(favorites.stops) { stop in
                        Button {
                            viewModel.select(stop)
                            onSelect()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stop.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                                Text(stop.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { favorites.remove(at: $0) }
                }
            }
            .navigationTitle("Favorites")
            .toolbar { if !favorites.stops.isEmpty { EditButton() } }
        }
    }
}

// MARK: - Feedback tab

struct FeedbackView: View {
    private var feedbackURL: URL {
        let message = "Hi SG Bus Live team! I'd like to share feedback:\n\nFeature request / bug: "
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/6588666375?text=\(encoded)")!
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Link(destination: feedbackURL) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Suggest a feature or report a bug").foregroundStyle(.primary)
                                Text("Chat with us on WhatsApp").font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(.green)
                        }
                    }
                } footer: {
                    Text("Opens WhatsApp to +65 8866 6375. Tell us what to improve or what's broken.")
                }
            }
            .navigationTitle("Feedback")
        }
    }
}

// MARK: - About tab

struct AboutView: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SG Bus Live").font(.title2.weight(.bold))
                        Text("Live Singapore bus arrival times. Find the bus stops nearest you with GPS, search by postal code or bus stop ID, save your regular stops to Favorites, and tap a bus number to track its next arrivals.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Developer") {
                    Label("Tertiary Infotech Academy Pte Ltd", systemImage: "building.2.fill")
                    Link(destination: URL(string: "https://www.tertiaryinfotech.com")!) {
                        Label("tertiaryinfotech.com", systemImage: "globe")
                    }
                }

                Section("Data") {
                    Text("Bus arrival and bus stop data from Singapore's LTA DataMall. Postal-code search powered by OneMap.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Version", value: version)
                }
            }
            .navigationTitle("About")
        }
    }
}

// MARK: - Shared subviews

private struct StopRow: View {
    let stop: BusStop
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text(stop.subtitle)
                        if let distanceText = stop.distanceText {
                            Text("·").foregroundStyle(.tertiary)
                            Text(distanceText)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }
    }
}

private struct StopHeader: View {
    let stop: BusStop
    let updatedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(stop.code, systemImage: "signpost.right")
                .font(.headline)
            Text(stop.title)
                .font(.title3.weight(.semibold))
            Text(stop.roadName)
                .foregroundStyle(.secondary)
            if let updatedAt {
                Text("Updated \(updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ServiceFilterRow: View {
    let serviceNumbers: [String]
    let selected: String?
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(serviceNumbers, id: \.self) { number in
                    let isOn = number == selected
                    Button { onTap(number) } label: {
                        Text(number)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isOn ? Color.green : Color(.secondarySystemGroupedBackground),
                                        in: Capsule())
                            .foregroundStyle(isOn ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

private struct ServiceArrivalRow: View {
    let service: BusService

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(service.serviceNo)
                .font(.title3.weight(.bold))
                .frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ArrivalPill(bus: service.nextBus)
                    ArrivalPill(bus: service.nextBus2)
                    ArrivalPill(bus: service.nextBus3)
                }
                Text(service.operatorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ArrivalPill: View {
    let bus: NextBus

    var body: some View {
        VStack(spacing: 2) {
            Text(bus.arrivalText)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            Text(bus.loadText.isEmpty ? bus.typeText : bus.loadText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 58, minHeight: 44)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}
