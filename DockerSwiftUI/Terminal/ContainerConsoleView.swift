import SwiftUI
import SpecttyTerminal

struct ContainerConsoleView: View {
    let containerId: String
    @State private var session: ConsoleSession?
    @State private var error: String?
    @State private var isConnecting = true

    var body: some View {
        Group {
            if let error {
                ContentUnavailableView("Console Error",
                    systemImage: "terminal",
                    description: Text(error))
            } else if isConnecting {
                ProgressView("Connecting...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let session {
                TerminalSwiftUIView(session: session)
            }
        }
        .task(id: containerId) {
            await connect()
        }
        .onDisappear {
            session?.disconnect()
            session = nil
        }
    }

    private func connect() async {
        session?.disconnect()
        isConnecting = true
        error = nil

        let newSession = ConsoleSession(containerId: containerId)
        do {
            try newSession.start()
            session = newSession
            isConnecting = false
        } catch {
            self.error = error.localizedDescription
            isConnecting = false
        }
    }
}

// MARK: - Console Session

@MainActor
final class ConsoleSession {
    let emulator: GhosttyTerminalEmulator
    let transport: DockerExecTransport
    private var receiveTask: Task<Void, Never>?

    init(containerId: String) {
        self.emulator = GhosttyTerminalEmulator(columns: 80, rows: 24, scrollbackCapacity: 10_000)
        self.transport = DockerExecTransport(containerId: containerId)

        // Wire up terminal responses (DSR, DA) back to the transport
        emulator.onResponse = { [weak self] data in
            self?.transport.send(data)
        }
    }

    func start() throws {
        try transport.connect()

        receiveTask = Task { [weak self] in
            guard let self else { return }
            for await data in transport.incomingData {
                self.emulator.feed(data)
            }
        }
    }

    func sendKey(_ data: Data) {
        transport.send(data)
    }

    func resize(columns: Int, rows: Int) {
        emulator.resize(columns: columns, rows: rows)
        transport.resize(columns: columns, rows: rows)
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        transport.disconnect()
    }
}

// MARK: - SwiftUI NSViewRepresentable

struct TerminalSwiftUIView: NSViewRepresentable {
    let session: ConsoleSession

    func makeNSView(context: Context) -> TerminalNSView {
        let view = TerminalNSView(emulator: session.emulator)

        view.onKeyData = { data in
            session.sendKey(data)
        }

        view.onResize = { cols, rows in
            session.resize(columns: cols, rows: rows)
        }

        return view
    }

    func updateNSView(_ nsView: TerminalNSView, context: Context) {
        // Emulator is shared, no update needed
    }
}
