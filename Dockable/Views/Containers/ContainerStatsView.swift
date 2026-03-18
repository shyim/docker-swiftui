import SwiftUI

struct ContainerStatsView: View {
    let containerId: String
    @Environment(DockerClient.self) private var client
    @State private var stats: ContainerStats?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if let stats {
                ScrollView {
                    VStack(spacing: 24) {
                        HStack(spacing: 40) {
                            StatGauge(
                                title: "CPU",
                                value: stats.cpuPercent,
                                maxValue: 100,
                                format: "%.1f%%",
                                color: .blue
                            )
                            StatGauge(
                                title: "Memory",
                                value: stats.memoryPercent,
                                maxValue: 100,
                                format: "%.1f%%",
                                color: .green
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Memory Usage")
                                .font(.headline)
                            ProgressView(value: stats.memoryPercent, total: 100)
                                .tint(.green)
                            HStack {
                                Text(formatBytes(stats.memoryUsage))
                                    .font(.caption)
                                Spacer()
                                Text(formatBytes(stats.memoryLimit))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        if let networks = stats.networks, !networks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Network I/O")
                                    .font(.headline)
                                HStack(spacing: 24) {
                                    VStack(alignment: .leading) {
                                        Text("Received")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatBytes(stats.totalRxBytes))
                                            .font(.title3)
                                            .fontWeight(.medium)
                                    }
                                    VStack(alignment: .leading) {
                                        Text("Sent")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatBytes(stats.totalTxBytes))
                                            .font(.title3)
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                }
            } else if isLoading {
                ProgressView("Loading stats...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView("Stats Unavailable",
                    systemImage: "chart.bar",
                    description: Text(error))
            }
        }
        .task(id: containerId) {
            await pollStats()
        }
    }

    private func pollStats() async {
        isLoading = true
        while !Task.isCancelled {
            do {
                stats = try await client.fetchStats(for: containerId)
                isLoading = false
                error = nil
            } catch {
                if stats == nil {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

struct StatGauge: View {
    let title: String
    let value: Double
    let maxValue: Double
    let format: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(value / maxValue, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: value)
                Text(String(format: format, value))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(width: 100, height: 100)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
