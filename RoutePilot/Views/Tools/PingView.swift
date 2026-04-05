//
//  PingView.swift
//  RoutePilot
//

import SwiftUI

/// Ping 测试组件
struct PingView: View {
    @State private var pingTarget: String = ""
    @State private var pingResults: [String] = []
    @State private var isPinging = false
    @State private var pingProcess: Process?
    @State private var pingStats: (packetLoss: String, avgLatency: String)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tools.ping".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("tools.ping_desc".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                ClearableTextField(placeholder: "input.target".localized, text: $pingTarget)
                    .disabled(isPinging)

                if isPinging {
                    Button("tools.stop".localized) {
                        stopPing()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("tools.test".localized) {
                        startPing()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(pingTarget.isEmpty)
                }
            }

            if !pingResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(pingResults, id: \.self) { result in
                            Text(result)
                                .font(.system(.caption2, design: .monospaced))
                        }
                    }
                }
                .frame(maxHeight: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cardBackground)
                )
            }

            // 统计摘要
            if let stats = pingStats {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("result.packet_loss".localized + ":")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(stats.packetLoss)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(stats.packetLoss == "0%" ? .green : .orange)
                    }
                    HStack(spacing: 4) {
                        Text("result.avg_latency".localized + ":")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(stats.avgLatency)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cardBackground)
        )
    }

    private func startPing() {
        guard !pingTarget.isEmpty else { return }
        isPinging = true
        pingResults = []
        pingStats = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "4", "-W", "2000", pingTarget]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let line = String(data: data, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                self.pingResults.append(line.trimmingCharacters(in: .newlines))
            }
        }

        do {
            try process.run()
            pingProcess = process

            process.terminationHandler = { _ in
                DispatchQueue.main.async {
                    self.isPinging = false
                    self.pingProcess = nil
                    self.parsePingStats()
                }
            }
        } catch {
            isPinging = false
        }
    }

    private func stopPing() {
        pingProcess?.terminate()
        pingProcess = nil
        isPinging = false
    }

    private func parsePingStats() {
        // 解析丢包率: "4 packets transmitted, 4 packets received, 0.0% packet loss"
        // 解析延迟: "round-trip min/avg/max/stddev = 20.123/25.456/30.789/5.123 ms"
        var packetLoss: String?
        var avgLatency: String?

        for result in pingResults {
            // 解析丢包率
            if result.contains("packet loss") {
                let pattern = #"(\d+\.?\d*)% packet loss"#
                if let range = result.range(of: pattern, options: .regularExpression) {
                    let match = String(result[range])
                    if let percentRange = match.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
                        let percent = String(match[percentRange])
                        if let value = Double(percent) {
                            packetLoss = value < 1 ? "0%" : String(format: "%.1f%%", value)
                        }
                    }
                }
            }

            // 解析平均延迟
            if result.contains("round-trip") || result.contains("rtt") {
                // 格式: round-trip min/avg/max/stddev = 20.123/25.456/30.789/5.123 ms
                let pattern = #"= (\d+\.?\d*)/(\d+\.?\d*)/(\d+\.?\d*)/(\d+\.?\d*) ms"#
                if let range = result.range(of: pattern, options: .regularExpression) {
                    let match = String(result[range])
                    let numbers = match.components(separatedBy: "/")
                    if numbers.count >= 2 {
                        let avgStr = numbers[1].replacingOccurrences(of: "= ", with: "")
                        if let avg = Double(avgStr) {
                            avgLatency = String(format: "%.1f ms", avg)
                        }
                    }
                }
            }
        }

        if let loss = packetLoss, let latency = avgLatency {
            pingStats = (packetLoss: loss, avgLatency: latency)
        }
    }
}