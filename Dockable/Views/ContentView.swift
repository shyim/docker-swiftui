import SwiftUI

struct ContentView: View {
    @Environment(DockerClient.self) private var client
    @State private var selectedSidebarItem: SidebarItem? = .containers
    @State private var selectedContainerId: String?
    @State private var selectedImageId: String?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem)
        } content: {
            Group {
                switch selectedSidebarItem {
                case .containers:
                    ContainerListView(selectedId: $selectedContainerId)
                case .images:
                    ImageListView(selectedId: $selectedImageId)
                case .volumes:
                    VolumeListView()
                case .networks:
                    NetworkListView()
                case nil:
                    ContentUnavailableView("Select a Category",
                        systemImage: "sidebar.left",
                        description: Text("Choose a section from the sidebar"))
                }
            }
        } detail: {
            if selectedSidebarItem == .containers, let id = selectedContainerId {
                ContainerDetailView(containerId: id)
            } else if selectedSidebarItem == .images, let id = selectedImageId {
                ImageDetailView(imageId: id)
            }
        }
        .onChange(of: selectedSidebarItem) {
            selectedContainerId = nil
            selectedImageId = nil
        }
        .task {
            await client.loadAll()
            client.startEventStream()
        }
        .alert("Error", isPresented: .init(
            get: { client.lastError != nil },
            set: { if !$0 { client.lastError = nil } }
        )) {
            Button("OK") { client.lastError = nil }
            Button("Retry") { Task { await client.loadAll() } }
        } message: {
            Text(client.lastError ?? "")
        }
    }
}
