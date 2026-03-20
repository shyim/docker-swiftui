import SwiftUI

struct ImageListView: View {
    @Environment(DockerClient.self) private var client
    @Binding var selectedId: String?
    @State private var searchText = ""

    private var filteredImages: [DockerImage] {
        client.images
            .filter {
                searchText.isEmpty
                    || $0.displayName.localizedCaseInsensitiveContains(searchText)
                    || $0.repository.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.created > $1.created }
    }

    var body: some View {
        List(filteredImages, selection: $selectedId) { image in
            ImageRowView(image: image)
                .tag(image.id)
                .contextMenu {
                    Button(role: .destructive) {
                        Task { await client.removeImage(image.id) }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Filter images...")
        .navigationTitle("Images")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await client.loadImages() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .overlay {
            if filteredImages.isEmpty && !client.isLoading {
                ContentUnavailableView("No Images",
                    systemImage: "opticaldisc",
                    description: Text(searchText.isEmpty ? "No Docker images found" : "No matches for \"\(searchText)\""))
            }
        }
    }
}

struct ImageRowView: View {
    let image: DockerImage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "opticaldisc")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(image.repository)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    Text(image.tag)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(image.shortId)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospaced()
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteCountFormatter.string(fromByteCount: image.size, countStyle: .file))
                    .font(.caption)
                    .monospacedDigit()
                Text(image.createdDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
