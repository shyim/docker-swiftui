import Foundation

enum SocketPathResolver {
    /// Resolves the Docker socket path by checking:
    /// 1. DOCKER_HOST environment variable
    /// 2. Active Docker context from ~/.docker/config.json
    /// 3. Common well-known socket paths
    static func resolve() -> String {
        // 1. Check DOCKER_HOST env var
        if let dockerHost = ProcessInfo.processInfo.environment["DOCKER_HOST"] {
            let path = dockerHost.replacingOccurrences(of: "unix://", with: "")
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // 2. Check active Docker context
        if let contextPath = resolveFromDockerContext() {
            return contextPath
        }

        // 3. Try common paths
        let commonPaths = [
            "\(NSHomeDirectory())/.colima/default/docker.sock",
            "/var/run/docker.sock",
            "\(NSHomeDirectory())/.orbstack/run/docker.sock",
            "\(NSHomeDirectory())/.docker/run/docker.sock",
            "\(NSHomeDirectory())/.lima/default/sock/docker.sock",
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return "/var/run/docker.sock"
    }

    private static func resolveFromDockerContext() -> String? {
        let configPath = "\(NSHomeDirectory())/.docker/config.json"
        let contextsDir = "\(NSHomeDirectory())/.docker/contexts/meta"

        guard let configData = FileManager.default.contents(atPath: configPath),
              let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
              let currentContext = config["currentContext"] as? String,
              currentContext != "default"
        else {
            return nil
        }

        // Scan context metadata directories
        guard let contextDirs = try? FileManager.default.contentsOfDirectory(atPath: contextsDir) else {
            return nil
        }

        for dir in contextDirs {
            let metaPath = "\(contextsDir)/\(dir)/meta.json"
            guard let metaData = FileManager.default.contents(atPath: metaPath),
                  let meta = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
                  let name = meta["Name"] as? String,
                  name == currentContext,
                  let endpoints = meta["Endpoints"] as? [String: Any],
                  let docker = endpoints["docker"] as? [String: Any],
                  let host = docker["Host"] as? String
            else {
                continue
            }

            let path = host.replacingOccurrences(of: "unix://", with: "")
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }
}
