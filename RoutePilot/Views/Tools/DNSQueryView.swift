//
//  DNSQueryView.swift
//  RoutePilot
//

import SwiftUI

/// DNS 查询组件
struct DNSQueryView: View {
    @State private var dnsTarget: String = ""
    @State private var dnsRecords: [(type: String, value: String)] = []
    @State private var isQueryingDNS = false
    @State private var dnsError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DNS 查询")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("查询域名解析记录")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("输入域名", text: $dnsTarget)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .disabled(isQueryingDNS)
                    .onSubmit {
                        queryDNS()
                    }

                Button(isQueryingDNS ? "查询中..." : "查询") {
                    queryDNS()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(dnsTarget.isEmpty || isQueryingDNS)
            }

            if !dnsRecords.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(dnsRecords, id: \.value) { record in
                        HStack {
                            Text(record.type)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.blue)
                                .frame(width: 50, alignment: .leading)
                            Text(record.value)
                                .font(.system(.caption2, design: .monospaced))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }

            if let error = dnsError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func queryDNS() {
        guard !dnsTarget.isEmpty else { return }
        isQueryingDNS = true
        dnsRecords = []
        dnsError = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
        process.arguments = ["+short", dnsTarget, "ANY"]

        let pipe = Pipe()
        process.standardOutput = pipe

        Task {
            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                var records: [(type: String, value: String)] = []
                for line in output.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }

                    let type: String
                    if trimmed.contains(".") && !trimmed.hasPrefix("\"") {
                        if trimmed.allSatisfy({ $0.isNumber || $0 == "." }) {
                            type = "A"
                        } else {
                            type = "CNAME"
                        }
                    } else {
                        type = "TXT"
                    }
                    records.append((type: type, value: trimmed))
                }

                await MainActor.run {
                    isQueryingDNS = false
                    dnsRecords = records
                }
            } catch {
                await MainActor.run {
                    isQueryingDNS = false
                    dnsError = "查询失败"
                }
            }
        }
    }
}