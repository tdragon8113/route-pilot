//
//  PortTestView.swift
//  RoutePilot
//

import SwiftUI
import Network

/// 端口测试组件
struct PortTestView: View {
    @State private var portHost: String = ""
    @State private var portNumber: String = ""
    @State private var portResult: String?
    @State private var isTestingPort = false

    // 常用端口列表
    private let commonPorts: [(name: String, port: String)] = [
        ("SSH", "22"),
        ("HTTP", "80"),
        ("HTTPS", "443"),
        ("MySQL", "3306"),
        ("Redis", "6379"),
        ("Mongo", "27017")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("端口测试")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("测试 TCP 端口连通性")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("主机", text: $portHost)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(width: 120)

                TextField("端口", text: $portNumber)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(width: 60)

                Button(isTestingPort ? "测试中..." : "测试") {
                    testPort()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(portHost.isEmpty || portNumber.isEmpty || isTestingPort)
            }

            // 常用端口快捷选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(commonPorts, id: \.port) { item in
                        MiniQuickButton(
                            title: "\(item.name):\(item.port)",
                            isSelected: portNumber == item.port
                        ) {
                            portNumber = item.port
                        }
                    }
                }
            }

            if let result = portResult {
                Text(result)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(result.hasPrefix("✓") ? .green : .orange)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func testPort() {
        guard !portHost.isEmpty, !portNumber.isEmpty, let port = UInt16(portNumber) else { return }
        isTestingPort = true
        portResult = nil

        let host = NWEndpoint.Host(portHost)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            portResult = "✗ 无效的端口号"
            isTestingPort = false
            return
        }

        let connection = NWConnection(host: host, port: nwPort, using: .tcp)

        connection.stateUpdateHandler = { [self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.portResult = "✓ 端口 \(self.portNumber) 开放"
                    self.isTestingPort = false
                    connection.cancel()
                case .failed:
                    self.portResult = "✗ 端口 \(self.portNumber) 不可达"
                    self.isTestingPort = false
                default:
                    break
                }
            }
        }

        connection.start(queue: .global())

        // 5 秒超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [self] in
            if isTestingPort {
                portResult = "✗ 连接超时"
                isTestingPort = false
                connection.cancel()
            }
        }
    }
}