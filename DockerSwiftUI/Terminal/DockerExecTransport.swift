import Foundation

final class DockerExecTransport: @unchecked Sendable {
    private let containerId: String
    private let shell: String
    private var process: Process?
    private var masterFD: Int32 = -1

    private let _incomingData: AsyncStream<Data>.Continuation
    let incomingData: AsyncStream<Data>

    init(containerId: String, shell: String = "/bin/sh") {
        self.containerId = containerId
        self.shell = shell
        var continuation: AsyncStream<Data>.Continuation!
        self.incomingData = AsyncStream { continuation = $0 }
        self._incomingData = continuation
    }

    func connect() throws {
        var master: Int32 = 0
        var slave: Int32 = 0
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            throw DockerExecError.ptyFailed
        }
        self.masterFD = master

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: dockerPath())
        proc.arguments = ["exec", "-it", containerId, shell]

        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        proc.standardInput = slaveHandle
        proc.standardOutput = slaveHandle
        proc.standardError = slaveHandle

        try proc.run()
        close(slave)
        self.process = proc

        // Read loop on master FD
        let fd = master
        let continuation = _incomingData
        DispatchQueue.global(qos: .userInitiated).async {
            var buf = [UInt8](repeating: 0, count: 8192)
            while true {
                let n = read(fd, &buf, buf.count)
                if n <= 0 { break }
                let data = Data(buf[0..<n])
                continuation.yield(data)
            }
            continuation.finish()
        }
    }

    func send(_ data: Data) {
        guard masterFD >= 0 else { return }
        data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            _ = write(masterFD, base, ptr.count)
        }
    }

    func resize(columns: Int, rows: Int) {
        guard masterFD >= 0 else { return }
        var ws = winsize()
        ws.ws_col = UInt16(columns)
        ws.ws_row = UInt16(rows)
        _ = ioctl(masterFD, TIOCSWINSZ, &ws)
    }

    func disconnect() {
        process?.terminate()
        process = nil
        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }
        _incomingData.finish()
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    private func dockerPath() -> String {
        let paths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker",
        ]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return "/usr/local/bin/docker"
    }
}

enum DockerExecError: LocalizedError {
    case ptyFailed

    var errorDescription: String? {
        switch self {
        case .ptyFailed: return "Failed to create PTY pair"
        }
    }
}
