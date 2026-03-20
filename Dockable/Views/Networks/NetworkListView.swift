import SwiftUI

struct NetworkListView: View {
    @Environment(DockerClient.self) private var client
    @Binding var selectedId: String?
    @State private var searchText = ""

    private var filteredNetworks: [DockerNetwork] {
        client.networks
            .filter {
                searchText.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.driver.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.name < $1.name }
    }

    private var inUseNetworks: [DockerNetwork] {
        let idsInUse = client.networkIdsInUse
        return filteredNetworks.filter { idsInUse.contains($0.id) }
    }

    private var unusedNetworks: [DockerNetwork] {
        let idsInUse = client.networkIdsInUse
        return filteredNetworks.filter { !idsInUse.contains($0.id) }
    }

    var body: some View {
        List(selection: $selectedId) {
            if !inUseNetworks.isEmpty {
                Section("In Use") {
                    ForEach(inUseNetworks) { network in
                        NetworkRowView(network: network)
                            .tag(network.id)
                            .contextMenu {
                                if !network.isBuiltIn {
                                    Button(role: .destructive) {
                                        Task { await client.removeNetwork(network.id) }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }

            if !unusedNetworks.isEmpty {
                Section("Unused") {
                    ForEach(unusedNetworks) { network in
                        NetworkRowView(network: network)
                            .tag(network.id)
                            .contextMenu {
                                if !network.isBuiltIn {
                                    Button(role: .destructive) {
                                        Task { await client.removeNetwork(network.id) }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Filter networks...")
        .navigationTitle("Networks")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await client.loadNetworks() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .overlay {
            if filteredNetworks.isEmpty && !client.isLoading {
                ContentUnavailableView("No Networks",
                    systemImage: "network",
                    description: Text(searchText.isEmpty ? "No Docker networks found" : "No matches for \"\(searchText)\""))
            }
        }
    }
}

struct NetworkRowView: View {
    let network: DockerNetwork

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "network")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(network.name)
                        .font(.body)
                        .fontWeight(.medium)
                    if network.isBuiltIn {
                        Text("built-in")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Text(network.driver)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let subnet = network.subnet {
                        Text(subnet)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospaced()
                    }
                }
            }

            Spacer()

            Text(network.shortId)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospaced()
        }
        .padding(.vertical, 2)
    }
}
