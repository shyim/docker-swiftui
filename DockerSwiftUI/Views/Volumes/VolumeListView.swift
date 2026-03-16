import SwiftUI

struct VolumeListView: View {
    @Environment(DockerClient.self) private var client
    @State private var searchText = ""
    @State private var selectedId: String?

    private var filteredVolumes: [DockerVolume] {
        client.volumes
            .filter {
                searchText.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.driver.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        List(filteredVolumes, selection: $selectedId) { volume in
            VolumeRowView(volume: volume)
                .tag(volume.id)
                .contextMenu {
                    Button(role: .destructive) {
                        Task { await client.removeVolume(volume.name) }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Filter volumes...")
        .navigationTitle("Volumes")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await client.loadVolumes() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .overlay {
            if filteredVolumes.isEmpty && !client.isLoading {
                ContentUnavailableView("No Volumes",
                    systemImage: "externaldrive",
                    description: Text(searchText.isEmpty ? "No Docker volumes found" : "No matches for \"\(searchText)\""))
            }
        }
    }
}

struct VolumeRowView: View {
    let volume: DockerVolume

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "externaldrive")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(volume.mountpoint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(volume.driver)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
