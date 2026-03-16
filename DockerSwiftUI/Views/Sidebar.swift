import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case containers = "Containers"
    case images = "Images"
    case volumes = "Volumes"
    case networks = "Networks"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .containers: "shippingbox"
        case .images: "opticaldisc"
        case .volumes: "externaldrive"
        case .networks: "network"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Environment(DockerClient.self) private var client

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.allCases) { item in
                Label {
                    Text(item.rawValue)
                } icon: {
                    Image(systemName: item.systemImage)
                }
                .badge(badgeCount(for: item))
                .tag(item)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Docker")
        .safeAreaInset(edge: .bottom) {
            connectionStatus
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(client.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(client.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func badgeCount(for item: SidebarItem) -> Int {
        switch item {
        case .containers: client.containers.count
        case .images: client.images.count
        case .volumes: client.volumes.count
        case .networks: client.networks.count
        }
    }
}
