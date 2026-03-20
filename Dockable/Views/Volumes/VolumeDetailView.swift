import SwiftUI

struct VolumeDetailView: View {
    let volumeName: String
    @Environment(DockerClient.self) private var client

    private var volume: DockerVolume? {
        client.volumes.first { $0.name == volumeName }
    }

    var body: some View {
        if let volume {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DetailRow(label: "Name", value: volume.name)
                    if let createdAt = volume.createdAt {
                        DetailRow(label: "Created", value: createdAt)
                    }
                    DetailRow(label: "Driver", value: volume.driver)
                    DetailRow(label: "Mountpoint", value: volume.mountpoint)
                    DetailRow(label: "Scope", value: volume.scope)

                    if let labels = volume.labels, !labels.isEmpty {
                        DetailSectionHeader(title: "Labels")

                        DetailTableHeader(columns: ["Key", "Value"])
                        ForEach(labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            DetailTableRow(columns: [key, value])
                        }
                    }
                }
            }
            .navigationTitle(volume.name)
        } else {
            ContentUnavailableView("Volume Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected volume may have been removed"))
        }
    }
}
