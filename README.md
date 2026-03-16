# Docker SwiftUI

A native macOS application for managing Docker containers, Compose stacks, images, volumes, and networks. Built with SwiftUI and Apple's `Network.framework` — no third-party networking dependencies.

Communicates directly with the Docker Engine API over the Unix socket, making raw HTTP/1.1 requests via `NWConnection`.

![Docker SwiftUI Screenshot](https://i.imgur.com/0gWGVkH.png)

## Features

- **Containers** — View all running and stopped containers with status indicators. Start, stop, restart, and remove containers via context menus.
- **Compose Stacks** — Containers belonging to Docker Compose projects are automatically grouped into collapsible sections. Bulk start/stop/restart/remove entire stacks.
- **Container Details** — Inspect container configuration, labels, ports, and mounts. View logs with a native text editor (scrollable, selectable, monospaced). Monitor live CPU and memory usage with gauges that poll every 3 seconds.
- **Interactive Console** — Open a shell (`/bin/sh`) inside running containers directly from the app. Powered by [spectty](https://github.com/ocnc/spectty)'s terminal emulator with full VT100/xterm support, color rendering, and cursor handling via CoreText.
- **Images** — Browse all local images with repository, tag, size, and creation date. Remove images via context menu.
- **Volumes** — List all Docker volumes with driver and mount point info. Remove volumes via context menu.
- **Networks** — View networks with driver, scope, and subnet details. Built-in networks (bridge, host, none) are labeled and protected from deletion.
- **Menu Bar Icon** — Quick-access menu bar extra showing all Compose stacks and standalone containers with status indicators and start/stop/restart actions. The app stays alive in the menu bar when you close the window.
- **Real-time Updates** — Subscribes to the Docker event stream for automatic UI refresh when containers start, stop, or are removed.
- **Auto-detection** — Automatically finds the Docker socket by reading the active Docker context from `~/.docker/config.json`. Works with Docker Desktop, OrbStack, Colima, and Lima out of the box.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- A running Docker-compatible runtime (Docker Desktop, OrbStack, Colima, etc.)

## Getting Started

Clone the repository and build:

```sh
git clone https://github.com/your-username/docker-swiftui.git
cd docker-swiftui
make build
make run
```

Or open in Xcode:

```sh
open DockerSwiftUI.xcodeproj
```

Then build and run with ⌘R.

### Available Make targets

| Command | Description |
|---------|-------------|
| `make build` | Build the app (Debug) |
| `make run` | Build and launch the app |
| `make clean` | Remove build artifacts |

### Docker Socket Detection

The app automatically detects your Docker socket by checking (in order):

1. `DOCKER_HOST` environment variable
2. Active context from `~/.docker/config.json` → `~/.docker/contexts/meta/`
3. `~/.colima/default/docker.sock`
4. `/var/run/docker.sock`
5. `~/.orbstack/run/docker.sock`
6. `~/.docker/run/docker.sock`
7. `~/.lima/default/sock/docker.sock`

## Architecture

```
DockerSwiftUI/
├── DockerSwiftUIApp.swift          # App entry point, menu bar extra
├── AppDelegate.swift               # Keeps app alive when window closes
├── Models/                         # Codable types for Docker API responses
│   ├── DockerContainer.swift
│   ├── DockerImage.swift
│   ├── DockerVolume.swift
│   ├── DockerNetwork.swift
│   ├── ContainerStats.swift
│   └── DockerEvent.swift
├── Networking/
│   ├── DockerSocket.swift          # Actor: raw HTTP/1.1 over Unix socket (NWConnection)
│   └── DockerAPI.swift             # Typed endpoint methods with JSON decoding
├── ViewModels/
│   └── DockerClient.swift          # @Observable state manager, event stream, actions
├── Terminal/
│   ├── DockerExecTransport.swift   # PTY-based docker exec transport
│   ├── TerminalNSView.swift        # CoreText terminal renderer (NSView)
│   └── ContainerConsoleView.swift  # SwiftUI wrapper + session management
├── Utilities/
│   ├── LogParser.swift             # Docker multiplexed log stream parser
│   └── SocketPathResolver.swift    # Auto-detects Docker socket path
├── Views/
│   ├── ContentView.swift           # NavigationSplitView (sidebar/content/detail)
│   ├── Sidebar.swift               # Section navigation with badge counts
│   ├── Containers/
│   │   ├── ContainerListView.swift # Grouped list with Compose disclosure groups
│   │   ├── ContainerDetailView.swift # Inspect/Logs/Console/Stats tabs
│   │   ├── ContainerLogView.swift  # NSTextView-based log viewer
│   │   └── ContainerStatsView.swift # CPU/memory gauges
│   ├── Images/
│   │   └── ImageListView.swift
│   ├── Volumes/
│   │   └── VolumeListView.swift
│   └── Networks/
│       └── NetworkListView.swift
└── Packages/
    └── SpecttyTerminal/            # VT100/xterm terminal emulator (from spectty)
```

### Networking

Two-layer architecture with no external dependencies:

- **`DockerSocket`** (actor) — Creates a `NWConnection` to the Unix socket per request. Builds raw HTTP/1.1 request strings, parses responses including chunked transfer encoding, and supports streaming for the Docker event API.
- **`DockerAPI`** — Typed Swift methods (`listContainers()`, `startContainer(id:)`, etc.) that call `DockerSocket` and decode JSON responses into Codable model types.

### State Management

`DockerClient` is an `@Observable @MainActor` class injected via SwiftUI's environment. It manages all app state, handles API calls, and maintains a background task for the Docker event stream that triggers automatic refreshes.

### Terminal Emulator

The interactive console uses [spectty](https://github.com/ocnc/spectty)'s `SpecttyTerminal` package — a pure-Swift VT100/xterm state machine with key encoding and scrollback support. The rendering is done with a custom `NSView` using CoreText, connected to `docker exec -it` via a PTY pair.

## Docker API

Targets Docker Engine API **v1.47**:

| Endpoint | Purpose |
|----------|---------|
| `GET /containers/json` | List containers |
| `POST /containers/{id}/start\|stop\|restart` | Container lifecycle |
| `DELETE /containers/{id}` | Remove container |
| `GET /containers/{id}/logs` | Fetch container logs |
| `GET /containers/{id}/stats` | Container CPU/memory stats |
| `GET /images/json` | List images |
| `DELETE /images/{id}` | Remove image |
| `GET /volumes` | List volumes |
| `DELETE /volumes/{name}` | Remove volume |
| `GET /networks` | List networks |
| `DELETE /networks/{id}` | Remove network |
| `GET /events` | Real-time event stream |

Compose stacks are derived from the `com.docker.compose.project` container label.

## App Sandbox

App Sandbox is **disabled** because macOS sandboxing blocks access to Unix sockets outside the app container. This means the app cannot be distributed via the Mac App Store but works fine as a direct download or via Homebrew.

## License

MIT
