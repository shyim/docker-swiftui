import SwiftUI

@main
struct DockerSwiftUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var client = DockerClient()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Docker", id: "main") {
            ContentView()
                .environment(client)
        }
        .defaultSize(width: 1100, height: 700)

        MenuBarExtra {
            MenuBarView()
                .environment(client)
        } label: {
            Image(systemName: "shippingbox.fill")
        }
    }
}

struct MenuBarView: View {
    @Environment(DockerClient.self) private var client
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Connection status
        HStack(spacing: 6) {
            Circle()
                .fill(client.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(client.isConnected ? "Connected" : "Disconnected")
        }

        Text("\(client.runningContainerCount) running / \(client.containers.count) total")
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()

        // Compose stacks
        if !client.composeProjects.isEmpty {
            ForEach(client.composeProjects.keys.sorted(), id: \.self) { project in
                let containers = client.composeProjects[project] ?? []
                let running = containers.filter(\.isRunning).count
                let allRunning = running == containers.count

                Menu {
                    if running > 0 {
                        Button("Stop All") {
                            Task {
                                for c in containers where c.isRunning {
                                    await client.stopContainer(c.id)
                                }
                            }
                        }
                        Button("Restart All") {
                            Task {
                                for c in containers {
                                    await client.restartContainer(c.id)
                                }
                            }
                        }
                    }
                    if running < containers.count {
                        Button("Start All") {
                            Task {
                                for c in containers where !c.isRunning {
                                    await client.startContainer(c.id)
                                }
                            }
                        }
                    }

                    Divider()

                    ForEach(containers) { container in
                        Menu(container.composeService ?? container.displayName) {
                            if container.isRunning {
                                Button("Stop") {
                                    Task { await client.stopContainer(container.id) }
                                }
                                Button("Restart") {
                                    Task { await client.restartContainer(container.id) }
                                }
                            } else {
                                Button("Start") {
                                    Task { await client.startContainer(container.id) }
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: allRunning ? "circle.fill" : (running > 0 ? "circle.lefthalf.filled" : "circle"))
                            .foregroundStyle(allRunning ? .green : (running > 0 ? .orange : .secondary))
                            .font(.caption2)
                        Text(project)
                        Spacer()
                        Text("\(running)/\(containers.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        // Standalone containers
        let standalone = client.standaloneContainers
        if !standalone.isEmpty {
            if !client.composeProjects.isEmpty {
                Divider()
            }

            ForEach(standalone) { container in
                Menu {
                    if container.isRunning {
                        Button("Stop") {
                            Task { await client.stopContainer(container.id) }
                        }
                        Button("Restart") {
                            Task { await client.restartContainer(container.id) }
                        }
                    } else {
                        Button("Start") {
                            Task { await client.startContainer(container.id) }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: container.isRunning ? "circle.fill" : "circle")
                            .foregroundStyle(container.isRunning ? .green : .secondary)
                            .font(.caption2)
                        Text(container.displayName)
                    }
                }
            }
        }

        Divider()

        Button("Open Docker Manager") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")

        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
