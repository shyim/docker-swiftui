import SwiftUI

struct ComposeStackView: View {
    @Environment(DockerClient.self) private var client
    @Binding var selectedId: String?

    var body: some View {
        Group {
            if client.composeProjects.isEmpty {
                ContentUnavailableView("No Compose Stacks",
                    systemImage: "square.stack.3d.up.slash",
                    description: Text("No containers with Docker Compose labels found"))
            } else {
                List(selection: $selectedId) {
                    ForEach(client.composeProjects.keys.sorted(), id: \.self) { project in
                        Section {
                            ForEach(client.composeProjects[project] ?? []) { container in
                                ComposeContainerRow(container: container, project: project)
                                    .tag(container.id)
                                    .contextMenu {
                                        ContainerContextMenu(container: container)
                                    }
                            }
                        } header: {
                            ComposeStackHeader(
                                project: project,
                                containers: client.composeProjects[project] ?? []
                            )
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Compose Stacks")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await client.loadContainers() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

struct ComposeStackHeader: View {
    let project: String
    let containers: [DockerContainer]

    private var runningCount: Int {
        containers.filter(\.isRunning).count
    }

    var body: some View {
        HStack {
            Image(systemName: "square.stack.3d.up")
                .foregroundStyle(.secondary)
            Text(project)
                .font(.headline)
            Spacer()
            Text("\(runningCount)/\(containers.count) running")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(runningCount == containers.count ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

struct ComposeContainerRow: View {
    let container: DockerContainer
    let project: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(container.isRunning ? .green : (container.state == "paused" ? .yellow : .red))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(container.composeService ?? container.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
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
}
