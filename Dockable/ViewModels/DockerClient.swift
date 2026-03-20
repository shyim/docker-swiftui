import Foundation
import Observation

@Observable
@MainActor
final class DockerClient {
    var containers: [DockerContainer] = []
    var images: [DockerImage] = []
    var volumes: [DockerVolume] = []
    var networks: [DockerNetwork] = []
    var isConnected: Bool = false
    var isLoading: Bool = false
    var lastError: String?

    private let api: DockerAPI
    private var eventStreamTask: Task<Void, Never>?

    init(socketPath: String? = nil) {
        let path = socketPath ?? SocketPathResolver.resolve()
        self.api = DockerAPI(socketPath: path)
    }

    // MARK: - Computed

    var composeProjects: [String: [DockerContainer]] {
        Dictionary(grouping: containers.filter { $0.composeProject != nil }) {
            $0.composeProject!
        }
    }

    var standaloneContainers: [DockerContainer] {
        containers.filter { $0.composeProject == nil }
    }

    var runningContainerCount: Int {
        containers.filter(\.isRunning).count
    }

    var imageIdsInUse: Set<String> {
        Set(containers.map(\.imageID))
    }

    var networkIdsInUse: Set<String> {
        var ids = Set<String>()
        for container in containers {
            guard let networks = container.networkSettings?.networks else { continue }
            for (_, endpoint) in networks {
                if let networkID = endpoint.networkID {
                    ids.insert(networkID)
                }
            }
        }
        return ids
    }

    var volumeNamesInUse: Set<String> {
        var names = Set<String>()
        for container in containers {
            guard let mounts = container.mounts else { continue }
            for mount in mounts where mount.type == "volume" {
                if let name = mount.name {
                    names.insert(name)
                }
            }
        }
        return names
    }

    // MARK: - Data Loading

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let c = api.listContainers(all: true)
            async let i = api.listImages()
            async let v = api.listVolumes()
            async let n = api.listNetworks()

            containers = try await c
            images = try await i
            volumes = try await v
            networks = try await n

            isConnected = true
            lastError = nil
        } catch {
            isConnected = false
            lastError = error.localizedDescription
        }
    }

    func loadContainers() async {
        do {
            containers = try await api.listContainers(all: true)
            isConnected = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadImages() async {
        do {
            images = try await api.listImages()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadVolumes() async {
        do {
            volumes = try await api.listVolumes()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadNetworks() async {
        do {
            networks = try await api.listNetworks()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Container Actions

    func startContainer(_ id: String) async {
        do {
            try await api.startContainer(id: id)
            await loadContainers()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stopContainer(_ id: String) async {
        do {
            try await api.stopContainer(id: id)
            await loadContainers()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restartContainer(_ id: String) async {
        do {
            try await api.restartContainer(id: id)
            await loadContainers()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func removeContainer(_ id: String, force: Bool = false) async {
        do {
            try await api.removeContainer(id: id, force: force)
            await loadContainers()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Image Actions

    func inspectImage(_ id: String) async throws -> DockerImageInspect {
        try await api.inspectImage(id: id)
    }

    func removeImage(_ id: String, force: Bool = false) async {
        do {
            try await api.removeImage(id: id, force: force)
            await loadImages()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Volume Actions

    func removeVolume(_ name: String) async {
        do {
            try await api.removeVolume(name: name)
            await loadVolumes()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Network Actions

    func removeNetwork(_ id: String) async {
        do {
            try await api.removeNetwork(id: id)
            await loadNetworks()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Logs & Stats

    func fetchLogs(for containerId: String, tail: Int = 500) async throws -> String {
        try await api.containerLogs(id: containerId, tail: tail)
    }

    func fetchStats(for containerId: String) async throws -> ContainerStats {
        try await api.containerStats(id: containerId)
    }

    // MARK: - Event Stream

    func startEventStream() {
        eventStreamTask?.cancel()
        eventStreamTask = Task {
            while !Task.isCancelled {
                do {
                    for try await event in await api.eventStream() {
                        await handleEvent(event)
                    }
                } catch {
                    if !Task.isCancelled {
                        isConnected = false
                        try? await Task.sleep(for: .seconds(5))
                    }
                }
            }
        }
    }

    func stopEventStream() {
        eventStreamTask?.cancel()
        eventStreamTask = nil
    }

    private func handleEvent(_ event: DockerEvent) async {
        switch event.type {
        case "container":
            await loadContainers()
        case "image":
            await loadImages()
        case "volume":
            await loadVolumes()
        case "network":
            await loadNetworks()
        default:
            break
        }
    }
}
