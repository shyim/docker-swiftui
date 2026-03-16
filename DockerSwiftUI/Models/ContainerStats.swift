import Foundation

struct ContainerStats: Codable, Sendable {
    let cpuStats: CPUStats
    let precpuStats: CPUStats
    let memoryStats: MemoryStats
    let networks: [String: NetworkStats]?

    struct CPUStats: Codable, Sendable {
        let cpuUsage: CPUUsage
        let systemCpuUsage: UInt64?
        let onlineCpus: Int?

        struct CPUUsage: Codable, Sendable {
            let totalUsage: UInt64

            enum CodingKeys: String, CodingKey {
                case totalUsage = "total_usage"
            }
        }

        enum CodingKeys: String, CodingKey {
            case cpuUsage = "cpu_usage"
            case systemCpuUsage = "system_cpu_usage"
            case onlineCpus = "online_cpus"
        }
    }

    struct MemoryStats: Codable, Sendable {
        let usage: UInt64?
        let limit: UInt64?

        enum CodingKeys: String, CodingKey {
            case usage
            case limit
        }
    }

    struct NetworkStats: Codable, Sendable {
        let rxBytes: UInt64
        let txBytes: UInt64

        enum CodingKeys: String, CodingKey {
            case rxBytes = "rx_bytes"
            case txBytes = "tx_bytes"
        }
    }

    var cpuPercent: Double {
        let cpuDelta = Double(cpuStats.cpuUsage.totalUsage) - Double(precpuStats.cpuUsage.totalUsage)
        let systemDelta = Double(cpuStats.systemCpuUsage ?? 0) - Double(precpuStats.systemCpuUsage ?? 0)
        guard systemDelta > 0 else { return 0 }
        let cpuCount = Double(cpuStats.onlineCpus ?? 1)
        return (cpuDelta / systemDelta) * cpuCount * 100.0
    }

    var memoryUsage: UInt64 { memoryStats.usage ?? 0 }
    var memoryLimit: UInt64 { memoryStats.limit ?? 0 }

    var memoryPercent: Double {
        guard memoryLimit > 0 else { return 0 }
        return Double(memoryUsage) / Double(memoryLimit) * 100.0
    }

    var totalRxBytes: UInt64 {
        networks?.values.reduce(0) { $0 + $1.rxBytes } ?? 0
    }

    var totalTxBytes: UInt64 {
        networks?.values.reduce(0) { $0 + $1.txBytes } ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case cpuStats = "cpu_stats"
        case precpuStats = "precpu_stats"
        case memoryStats = "memory_stats"
        case networks
    }
}
