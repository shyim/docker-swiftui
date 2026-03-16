import SwiftUI

struct ContainerListView: View {
    @Environment(DockerClient.self) private var client
    @Binding var selectedId: String?
    @State private var searchText = ""
    @State private var showAll = true

    private func matchesSearch(_ container: DockerContainer) -> Bool {
        searchText.isEmpty
            || container.displayName.localizedCaseInsensitiveContains(searchText)
            || container.image.localizedCaseInsensitiveContains(searchText)
            || (container.composeProject?.localizedCaseInsensitiveContains(searchText) ?? false)
    }

    private func filterContainer(_ container: DockerContainer) -> Bool {
        (showAll || container.isRunning) && matchesSearch(container)
    }

    /// Compose projects where at least one container matches the filter
    private var filteredProjects: [(String, [DockerContainer])] {
        client.composeProjects
            .map { (project, containers) in
                (project, containers.filter(filterContainer).sorted { $0.displayName < $1.displayName })
            }
            .filter { !$0.1.isEmpty }
            .sorted { $0.0 < $1.0 }
    }

    /// Standalone containers (not part of any compose project)
    private var filteredStandalone: [DockerContainer] {
        client.standaloneContainers
            .filter(filterContainer)
            .sorted { $0.created > $1.created }
    }

    var body: some View {
        List(selection: $selectedId) {
            // Compose stacks as collapsible groups
            ForEach(filteredProjects, id: \.0) { project, containers in
                ComposeDisclosureGroup(
                    project: project,
                    containers: containers
                )
            }

            // Standalone containers
            ForEach(filteredStandalone) { container in
                ContainerRowView(container: container)
                    .tag(container.id)
                    .contextMenu {
                        ContainerContextMenu(container: container)
                    }
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Filter containers...")
        .navigationTitle("Containers")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $showAll) {
                    Label("Show All", systemImage: showAll ? "eye" : "eye.slash")
                }
                .help(showAll ? "Showing all containers" : "Showing running only")
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await client.loadContainers() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .overlay {
            if filteredProjects.isEmpty && filteredStandalone.isEmpty && !client.isLoading {
                ContentUnavailableView("No Containers",
                    systemImage: "shippingbox",
                    description: Text(searchText.isEmpty ? "No containers found" : "No matches for \"\(searchText)\""))
            }
        }
    }
}

// MARK: - Compose Disclosure Group

struct ComposeDisclosureGroup: View {
    @Environment(DockerClient.self) private var client
    let project: String
    let containers: [DockerContainer]
    @State private var isExpanded = true
    @State private var showRemoveConfirmation = false

    private var runningCount: Int {
        containers.filter(\.isRunning).count
    }

    private var allRunning: Bool {
        runningCount == containers.count
    }

    private var anyRunning: Bool {
        runningCount > 0
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(containers) { container in
                ComposeServiceRow(container: container)
                    .tag(container.id)
                    .contextMenu {
                        ContainerContextMenu(container: container)
                    }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(anyRunning ? .blue : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(project)
                        .font(.body)
                        .fontWeight(.semibold)
                }

                Spacer()

                Text("\(runningCount)/\(containers.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(allRunning ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .contextMenu {
                if anyRunning {
                    Button {
                        Task {
                            for c in containers where c.isRunning {
                                await client.stopContainer(c.id)
                            }
                        }
                    } label: {
                        Label("Stop All", systemImage: "stop.fill")
                    }
                    Button {
                        Task {
                            for c in containers {
                                await client.restartContainer(c.id)
                            }
                        }
                    } label: {
                        Label("Restart All", systemImage: "arrow.clockwise")
                    }
                }
                if runningCount < containers.count {
                    Button {
                        Task {
                            for c in containers where !c.isRunning {
                                await client.startContainer(c.id)
                            }
                        }
                    } label: {
                        Label("Start All", systemImage: "play.fill")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    showRemoveConfirmation = true
                } label: {
                    Label("Remove All", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Remove all containers in \"\(project)\"?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove All", role: .destructive) {
                Task {
                    for c in containers {
                        await client.removeContainer(c.id, force: true)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will force-remove all \(containers.count) containers in this stack.")
        }
    }
}

struct ComposeServiceRow: View {
    let container: DockerContainer

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(container.composeService ?? container.displayName)
                    .font(.body)
                Text(container.image)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(container.status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch container.state {
        case "running": .green
        case "paused": .yellow
        case "exited": .red
        default: .gray
        }
    }
}

// MARK: - Standalone Container Row

struct ContainerRowView: View {
    let container: DockerContainer

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(container.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    Text(container.image)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !container.portSummary.isEmpty {
                        Text(container.portSummary)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Text(container.status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch container.state {
        case "running": .green
        case "paused": .yellow
        case "exited": .red
        default: .gray
        }
    }
}

struct ContainerContextMenu: View {
    @Environment(DockerClient.self) private var client
    let container: DockerContainer

    var body: some View {
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

        Divider()

        Button(role: .destructive) {
            Task { await client.removeContainer(container.id, force: !container.isRunning) }
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }
}
