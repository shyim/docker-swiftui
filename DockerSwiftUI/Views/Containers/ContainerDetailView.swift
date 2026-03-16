import SwiftUI

struct ContainerDetailView: View {
    let containerId: String
    @Environment(DockerClient.self) private var client
    @State private var selectedTab: DetailTab = .inspect

    enum DetailTab: String, CaseIterable {
        case inspect = "Inspect"
        case logs = "Logs"
        case console = "Console"
        case stats = "Stats"
    }

    private var container: DockerContainer? {
        client.containers.first { $0.id == containerId }
    }

    var body: some View {
        if let container {
            VStack(spacing: 0) {
                // Header
                ContainerDetailHeader(container: container)

                // Tab picker
                Picker("Tab", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab content
                Group {
                    switch selectedTab {
                    case .inspect:
                        ContainerInspectView(container: container)
                    case .logs:
                        ContainerLogView(containerId: container.id)
                    case .console:
                        if container.isRunning {
                            ContainerConsoleView(containerId: container.id)
                        } else {
                            ContentUnavailableView("Container Not Running",
                                systemImage: "terminal",
                                description: Text("Start the container to open a console"))
                        }
                    case .stats:
                        ContainerStatsView(containerId: container.id)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(container.displayName)
        } else {
            ContentUnavailableView("Container Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected container may have been removed"))
        }
    }
}

struct ContainerDetailHeader: View {
    @Environment(DockerClient.self) private var client
    let container: DockerContainer

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(container.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    StateBadge(state: container.state)
                }
                Text(container.image)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if container.isRunning {
                    Button {
                        Task { await client.stopContainer(container.id) }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    Button {
                        Task { await client.restartContainer(container.id) }
                    } label: {
                        Label("Restart", systemImage: "arrow.clockwise")
                    }
                } else {
                    Button {
                        Task { await client.startContainer(container.id) }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.bar)
    }
}

struct StateBadge: View {
    let state: String

    var body: some View {
        Text(state.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch state {
        case "running": .green
        case "paused": .yellow
        case "exited": .red
        default: .gray
        }
    }
}

struct ContainerInspectView: View {
    let container: DockerContainer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InfoSection(title: "General") {
                    InfoRow(label: "ID", value: container.shortId)
                    InfoRow(label: "Full ID", value: container.id, monospaced: true)
                    InfoRow(label: "Image", value: container.image)
                    InfoRow(label: "Command", value: container.command, monospaced: true)
                    InfoRow(label: "Created", value: Date(timeIntervalSince1970: TimeInterval(container.created)).formatted())
                    InfoRow(label: "Status", value: container.status)
                }

                if !container.ports.isEmpty {
                    InfoSection(title: "Ports") {
                        ForEach(container.ports.indices, id: \.self) { i in
                            let port = container.ports[i]
                            InfoRow(
                                label: "\(port.privatePort)/\(port.type)",
                                value: port.publicPort.map { "\(port.ip ?? "0.0.0.0"):\($0)" } ?? "Not published"
                            )
                        }
                    }
                }

                if !container.labels.isEmpty {
                    InfoSection(title: "Labels") {
                        ForEach(container.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            InfoRow(label: key, value: value)
                        }
                    }
                }

                if let mounts = container.mounts, !mounts.isEmpty {
                    InfoSection(title: "Mounts") {
                        ForEach(mounts.indices, id: \.self) { i in
                            let mount = mounts[i]
                            InfoRow(
                                label: mount.destination ?? "?",
                                value: "\(mount.type ?? "?") - \(mount.source ?? mount.name ?? "?")"
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
