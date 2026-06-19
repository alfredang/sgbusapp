import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BusArrivalsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StopHeader(stop: viewModel.selectedStop, updatedAt: viewModel.lastUpdated)
                    Button {
                        Task { await viewModel.loadArrivals() }
                    } label: {
                        Label(viewModel.isLoading ? "Refreshing" : "Refresh arrivals", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }

                Section("Bus Stop") {
                    TextField("Search stop code, road, or landmark", text: $viewModel.query)
                        .textInputAutocapitalization(.never)
                    ForEach(viewModel.filteredStops) { stop in
                        Button {
                            viewModel.select(stop)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stop.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(stop.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if stop == viewModel.selectedStop {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }

                Section("Arrivals") {
                    if viewModel.isLoading && viewModel.services.isEmpty {
                        ProgressView("Loading arrivals")
                    } else if let errorMessage = viewModel.errorMessage {
                        ContentUnavailableView(errorMessage, systemImage: "wifi.exclamationmark")
                    } else if viewModel.services.isEmpty {
                        ContentUnavailableView("No arrivals listed", systemImage: "bus")
                    } else {
                        ForEach(viewModel.services) { service in
                            ServiceArrivalRow(service: service)
                        }
                    }
                }
            }
            .navigationTitle("SG Bus")
            .task { await viewModel.loadArrivals() }
            .refreshable { await viewModel.loadArrivals() }
        }
    }
}

private struct StopHeader: View {
    let stop: BusStop
    let updatedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(stop.id, systemImage: "signpost.right")
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
