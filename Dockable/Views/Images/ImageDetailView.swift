import SwiftUI

struct ImageDetailView: View {
    let imageId: String
    @Environment(DockerClient.self) private var client
    @State private var inspect: DockerImageInspect?
    @State private var isLoading = false

    private var image: DockerImage? {
        client.images.first { $0.id == imageId }
    }

    var body: some View {
        if let image {
            VStack(spacing: 0) {
                ImageDetailHeader(image: image)

                ImageInspectView(image: image, inspect: inspect)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(image.displayName)
            .task(id: imageId) {
                await loadInspect()
            }
        } else {
            ContentUnavailableView("Image Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected image may have been removed"))
        }
    }

    private func loadInspect() async {
        isLoading = true
        defer { isLoading = false }
        do {
            inspect = try await client.inspectImage(imageId)
        } catch {
            inspect = nil
        }
    }
}

struct ImageDetailHeader: View {
    @Environment(DockerClient.self) private var client
    let image: DockerImage

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(image.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(image.shortId)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }

            Spacer()

            Button(role: .destructive) {
                Task { await client.removeImage(image.id) }
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.bar)
    }
}

struct ImageInspectView: View {
    let image: DockerImage
    let inspect: DockerImageInspect?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InfoSection(title: "General") {
                    InfoRow(label: "ID", value: inspect?.shortId ?? image.shortId, monospaced: true)
                    InfoRow(label: "Tag", value: image.displayName)
                    if let inspect, let date = inspect.createdDate {
                        InfoRow(label: "Created", value: date.formatted())
                    } else {
                        InfoRow(label: "Created", value: image.createdDate.formatted())
                    }
                    InfoRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: image.size, countStyle: .file))
                    if let inspect {
                        InfoRow(label: "Platform", value: inspect.platform)
                    }
                }

                if let config = inspect?.config {
                    InfoSection(title: "Config") {
                        if let user = config.user, !user.isEmpty {
                            InfoRow(label: "User", value: user)
                        }
                        if let cmd = config.cmd, !cmd.isEmpty {
                            InfoRow(label: "Command", value: cmd.joined(separator: " "), monospaced: true)
                        }
                        if let entrypoint = config.entrypoint, !entrypoint.isEmpty {
                            InfoRow(label: "Entrypoint", value: entrypoint.joined(separator: " "), monospaced: true)
                        }
                        if let workingDir = config.workingDir, !workingDir.isEmpty {
                            InfoRow(label: "Working Directory", value: workingDir, monospaced: true)
                        }
                        if let stopSignal = config.stopSignal, !stopSignal.isEmpty {
                            InfoRow(label: "Stop Signal", value: stopSignal)
                        }
                        if let ports = config.exposedPorts, !ports.isEmpty {
                            InfoRow(label: "Exposed Ports", value: ports.keys.sorted().joined(separator: ", "))
                        }
                    }
                }

                if let env = inspect?.config?.env, !env.isEmpty {
                    InfoSection(title: "Environment") {
                        ForEach(env.sorted(), id: \.self) { entry in
                            let parts = entry.split(separator: "=", maxSplits: 1)
                            let key = String(parts.first ?? "")
                            let value = parts.count > 1 ? String(parts[1]) : ""
                            InfoRow(label: key, value: value)
                        }
                    }
                }

                if let labels = inspect?.config?.labels, !labels.isEmpty {
                    InfoSection(title: "Labels") {
                        ForEach(labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            InfoRow(label: key, value: value)
                        }
                    }
                }
            }
            .padding()
        }
    }
}
