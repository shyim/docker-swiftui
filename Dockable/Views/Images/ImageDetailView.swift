import SwiftUI

struct ImageDetailView: View {
    let imageId: String
    @Environment(DockerClient.self) private var client
    @State private var inspect: DockerImageInspect?

    private var image: DockerImage? {
        client.images.first { $0.id == imageId }
    }

    var body: some View {
        if let image {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Top-level info rows
                    DetailRow(label: "ID", value: inspect?.shortId ?? image.shortId)
                    DetailRow(label: "Tag", value: image.displayName)
                    if let inspect, let date = inspect.createdDate {
                        DetailRow(label: "Created", value: date.formatted())
                    } else {
                        DetailRow(label: "Created", value: image.createdDate.formatted())
                    }
                    DetailRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: image.size, countStyle: .file))
                    if let inspect {
                        DetailRow(label: "Platform", value: inspect.platform)
                    }

                    // Config section
                    if let config = inspect?.config {
                        DetailSectionHeader(title: "Config")

                        if let user = config.user, !user.isEmpty {
                            DetailRow(label: "User", value: user)
                        }
                        if let cmd = config.cmd, !cmd.isEmpty {
                            DetailRow(label: "Command", value: cmd.joined(separator: " "))
                        }
                        if let entrypoint = config.entrypoint, !entrypoint.isEmpty {
                            DetailRow(label: "Entrypoint", value: entrypoint.joined(separator: " "))
                        }
                        if let workingDir = config.workingDir, !workingDir.isEmpty {
                            DetailRow(label: "Working Directory", value: workingDir)
                        }
                        if let stopSignal = config.stopSignal, !stopSignal.isEmpty {
                            DetailRow(label: "Stop Signal", value: stopSignal)
                        }
                        if let ports = config.exposedPorts, !ports.isEmpty {
                            DetailRow(label: "Exposed Ports", value: ports.keys.sorted().joined(separator: ", "))
                        }
                    }

                    // Environment section
                    if let env = inspect?.config?.env, !env.isEmpty {
                        DetailSectionHeader(title: "Environment")

                        DetailTableHeader(columns: ["Key", "Value"])
                        ForEach(env.sorted(), id: \.self) { entry in
                            let parts = entry.split(separator: "=", maxSplits: 1)
                            let key = String(parts.first ?? "")
                            let value = parts.count > 1 ? String(parts[1]) : ""
                            DetailTableRow(columns: [key, value])
                        }
                    }

                    // Labels section
                    if let labels = inspect?.config?.labels, !labels.isEmpty {
                        DetailSectionHeader(title: "Labels")

                        DetailTableHeader(columns: ["Key", "Value"])
                        ForEach(labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            DetailTableRow(columns: [key, value])
                        }
                    }
                }
            }
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
        do {
            inspect = try await client.inspectImage(imageId)
        } catch {
            inspect = nil
        }
    }
}
