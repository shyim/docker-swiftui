import SwiftUI

struct VolumeListView: View {
    @Environment(DockerClient.self) private var client
    @Binding var selectedId: String?
    @State private var searchText = ""

    private var filteredVolumes: [DockerVolume] {
        client.volumes
            .filter {
                searchText.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.driver.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.name < $1.name }
    }

    private var inUseVolumes: [DockerVolume] {
        let namesInUse = client.volumeNamesInUse
        return filteredVolumes.filter { namesInUse.contains($0.name) }
    }

    private var unusedVolumes: [DockerVolume] {
        let namesInUse = client.volumeNamesInUse
        return filteredVolumes.filter { !namesInUse.contains($0.name) }
    }

    var body: some View {
        List(selection: $selectedId) {
            if !inUseVolumes.isEmpty {
                Section("In Use") {
                    ForEach(inUseVolumes) { volume in
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
                }
            }

            if !unusedVolumes.isEmpty {
                Section("Unused") {
                    ForEach(unusedVolumes) { volume in
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
