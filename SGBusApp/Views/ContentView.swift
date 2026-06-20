import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BusArrivalsViewModel()

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

    // MARK: - Search

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

    // MARK: - Arrivals

    private var arrivalsSection: some View {
        Section {
            if let stop = viewModel.selectedStop {
                StopHeader(stop: stop, updatedAt: viewModel.lastUpdated)
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

// MARK: - Subviews

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
