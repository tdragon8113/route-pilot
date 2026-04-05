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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ping 测试")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("测试网络连通性")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                ClearableTextField(placeholder: "输入域名或 IP", text: $pingTarget)
                    .disabled(isPinging)

                if isPinging {
                    Button("停止") {
                        stopPing()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("测试") {
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
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func startPing() {
        guard !pingTarget.isEmpty else { return }
        isPinging = true
        pingResults = []

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
}