import SwiftUI

struct NetworkDetailView: View {
    let networkId: String
    @Environment(DockerClient.self) private var client

    private var network: DockerNetwork? {
        client.networks.first { $0.id == networkId }
    }

    var body: some View {
        if let network {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DetailRow(label: "Name", value: network.name)
                    DetailRow(label: "ID", value: network.shortId)
                    DetailRow(label: "Driver", value: network.driver)
                    DetailRow(label: "Scope", value: network.scope)
                    if let isInternal = network.isInternal {
                        DetailRow(label: "Internal", value: isInternal ? "Yes" : "No")
                    }

                    // IPAM config
                    if let configs = network.ipam?.config, !configs.isEmpty {
                        DetailSectionHeader(title: "IPAM")

                        if let ipamDriver = network.ipam?.driver {
                            DetailRow(label: "Driver", value: ipamDriver)
                        }
                        ForEach(Array(configs.enumerated()), id: \.offset) { index, config in
                            if let subnet = config.subnet {
                                DetailRow(label: configs.count > 1 ? "Subnet \(index + 1)" : "Subnet", value: subnet)
                            }
                            if let gateway = config.gateway {
                                DetailRow(label: configs.count > 1 ? "Gateway \(index + 1)" : "Gateway", value: gateway)
                            }
                        }
                    }

                    if let labels = network.labels, !labels.isEmpty {
                        DetailSectionHeader(title: "Labels")

                        DetailTableHeader(columns: ["Key", "Value"])
                        ForEach(labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            DetailTableRow(columns: [key, value])
                        }
                    }
                }
            }
            .navigationTitle(network.name)
        } else {
            ContentUnavailableView("Network Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected network may have been removed"))
        }
    }
}
