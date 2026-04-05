//
//  TracerouteView.swift
//  RoutePilot
//

import SwiftUI

/// 路由追踪组件
struct TracerouteView: View {
    @ObservedObject private var app = AppController.shared
    @State private var tracerouteTarget: String = ""
    @State private var tracerouteHops: [TracerouteHop] = []
    @State private var isTracing = false
    @State private var tracerouteError: String?
    @State private var tracerouteProcess: Process?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tools.traceroute".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("tools.traceroute_desc".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            // VPN 环境警告
            if !app.activeVPNs.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("traceroute.vpn_warning".localized)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            HStack {
                ClearableTextField(placeholder: "input.target".localized, text: $tracerouteTarget)
                    .disabled(isTracing)

                if isTracing {
                    Button("tools.cancel".localized) {
                        stopTraceroute()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("tools.start".localized) {
                        startTraceroute()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(tracerouteTarget.isEmpty)
                }
            }

            if !tracerouteHops.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(tracerouteHops) { hop in
                            HStack {
                                Text("\(hop.hopNumber)")
                                    .font(.caption2)
                                    .frame(width: 20, alignment: .leading)
                                    .foregroundColor(.secondary)

                                if let ip = hop.ip {
                                    Text(ip)
                                        .font(.caption2)
                                        .foregroundColor(.blue)

                                    if let time = hop.time {
                                        Text(time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("*")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 120)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cardBackground)
                )
            }

            if let error = tracerouteError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cardBackground)
        )
    }

    private func startTraceroute() {
        guard !tracerouteTarget.isEmpty else { return }
        isTracing = true
        tracerouteHops = []
        tracerouteError = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/traceroute")
        process.arguments = ["-w", "2", "-q", "1", "-m", "30", tracerouteTarget]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let line = String(data: data, encoding: .utf8) ?? ""

            if let hop = parseTracerouteLine(line) {
                DispatchQueue.main.async {
                    self.tracerouteHops.append(hop)
                }
            }
        }

        do {
            try process.run()
            tracerouteProcess = process

            process.terminationHandler = { _ in
                DispatchQueue.main.async {
                    self.isTracing = false
                    self.tracerouteProcess = nil
                }
            }
        } catch {
            isTracing = false
            tracerouteError = "error.operation_failed".localized
        }
    }

    private func stopTraceroute() {
        tracerouteProcess?.terminate()
        tracerouteProcess = nil
        isTracing = false
    }

    private func parseTracerouteLine(_ line: String) -> TracerouteHop? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("traceroute") { return nil }

        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard let hopNum = Int(parts[0]) else { return nil }

        if parts.count > 1 && String(parts[1]) == "*" {
            return TracerouteHop(hopNumber: hopNum, ip: nil, hostname: nil, time: nil)
        }

        guard parts.count > 1 else { return nil }

        let ip = String(parts[1])
        var time: String? = nil

        for i in 2..<parts.count {
            if parts[i].contains("ms") {
                time = String(parts[i])
                break
            }
        }

        return TracerouteHop(hopNumber: hopNum, ip: ip, hostname: nil, time: time)
    }
}